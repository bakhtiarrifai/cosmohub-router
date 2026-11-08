// claude-hub.exe: process wrapper for the Claude Code VS Code extension (setting claudeCode.claudeProcessWrapper).
// The extension runs:  claude-hub.exe <path-to-bundled-claude.exe> <claude args...>
// If the local CosmosHub router is usable, Claude is started with ANTHROPIC_BASE_URL pointing at it;
// otherwise Claude is started unchanged, i.e. on the subscription login. stdin/stdout/stderr are inherited,
// and a job object makes sure Claude exits when the extension kills this wrapper.
// Build: wrapper\build.ps1 (uses the C# compiler that ships with Windows).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;

static class ClaudeHub
{
    const string RouterUrl = "http://127.0.0.1:4141";

    static string StateDir { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".cosmohub"); } }

    static void Log(string line)
    {
        try
        {
            Directory.CreateDirectory(StateDir);
            File.AppendAllText(Path.Combine(StateDir, "wrapper.log"), DateTime.UtcNow.ToString("o") + " " + line + Environment.NewLine);
        }
        catch { }
    }

    static string Get(string url, int timeoutMs)
    {
        try
        {
            var req = (HttpWebRequest)WebRequest.Create(url);
            req.Timeout = timeoutMs;
            req.ReadWriteTimeout = timeoutMs;
            req.Proxy = null;
            using (var resp = (HttpWebResponse)req.GetResponse())
            using (var r = new StreamReader(resp.GetResponseStream()))
                return r.ReadToEnd();
        }
        catch { return null; }
    }

    static bool EnsureRouter()
    {
        if (Get(RouterUrl + "/health", 1500) != null) return true;
        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("COSMOSHUB_API_KEY")))
        {
            string k = Environment.GetEnvironmentVariable("COSMOSHUB_API_KEY", EnvironmentVariableTarget.User);
            if (string.IsNullOrEmpty(k)) return false;
            Environment.SetEnvironmentVariable("COSMOSHUB_API_KEY", k);
        }
        string exeDir = AppDomain.CurrentDomain.BaseDirectory;
        string router = Path.GetFullPath(Path.Combine(exeDir, "..", "router.js"));
        string node = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "nodejs", "node.exe");
        if (!File.Exists(router) || !File.Exists(node)) return false;
        try
        {
            // ShellExecute does not inherit our handles. With CreateProcess the long-lived router would keep
            // the extension's stdout pipe open and the extension would wait on it forever.
            var psi = new ProcessStartInfo(node, "\"" + router + "\"") { UseShellExecute = true, WindowStyle = ProcessWindowStyle.Hidden };
            Process.Start(psi);
        }
        catch { return false; }
        for (int i = 0; i < 40; i++)
        {
            System.Threading.Thread.Sleep(250);
            if (Get(RouterUrl + "/health", 1500) != null) return true;
        }
        return false;
    }

    // Standard Windows command-line quoting (CommandLineToArgvW rules).
    static string Quote(string a)
    {
        if (a.Length > 0 && a.IndexOfAny(new[] { ' ', '\t', '\n', '\v', '"' }) < 0) return a;
        var sb = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in a)
        {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') { sb.Append('\\', slashes * 2 + 1); sb.Append('"'); }
            else { sb.Append('\\', slashes); sb.Append(c); }
            slashes = 0;
        }
        sb.Append('\\', slashes * 2);
        sb.Append('"');
        return sb.ToString();
    }

    static int Main(string[] args)
    {
        if (args.Length == 0)
        {
            Console.Error.WriteLine("claude-hub: expected the path to claude.exe as the first argument");
            return 2;
        }
        string claude = args[0];
        var rest = new List<string>();
        for (int i = 1; i < args.Length; i++) rest.Add(Quote(args[i]));

        var psi = new ProcessStartInfo(claude, string.Join(" ", rest)) { UseShellExecute = false };

        string mode = "subscription";
        string reason = "";
        if (Environment.GetEnvironmentVariable("COSMOHUB_DISABLE") == "1") reason = "COSMOHUB_DISABLE=1";
        else if (!EnsureRouter()) reason = "router not running";
        else
        {
            string h = Get(RouterUrl + "/health?live=1", 45000);
            string tokenFile = Path.Combine(StateDir, "router-token");
            if (h == null) reason = "health check failed";
            else if (!h.Replace(" ", "").Contains("\"usable\":true")) reason = "router says not usable: " + h;
            else if (!File.Exists(tokenFile)) reason = "router token missing";
            else
            {
                mode = "cosmoshub";
                psi.EnvironmentVariables["ANTHROPIC_BASE_URL"] = RouterUrl;
                psi.EnvironmentVariables["ANTHROPIC_AUTH_TOKEN"] = File.ReadAllText(tokenFile).Trim();
                psi.EnvironmentVariables.Remove("ANTHROPIC_API_KEY");
                psi.EnvironmentVariables["ANTHROPIC_DEFAULT_OPUS_MODEL"] = "hub-opus";
                psi.EnvironmentVariables["ANTHROPIC_DEFAULT_SONNET_MODEL"] = "hub-sonnet";
                psi.EnvironmentVariables["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = "hub-haiku";
            }
        }
        string firstArgs = string.Join(" ", rest.GetRange(0, Math.Min(3, rest.Count)));
        Log(mode + (reason.Length > 0 ? " (" + reason + ")" : "") + " :: " + firstArgs);

        IntPtr job = CreateKillOnCloseJob();
        try
        {
            using (var p = Process.Start(psi))
            {
                if (job != IntPtr.Zero) AssignProcessToJobObject(job, p.Handle);
                p.WaitForExit();
                return p.ExitCode;
            }
        }
        catch (Exception e)
        {
            Console.Error.WriteLine("claude-hub: could not start " + claude + ": " + e.Message);
            return 1;
        }
    }

    // ---- job object: kill Claude when this wrapper goes away ----
    [StructLayout(LayoutKind.Sequential)]
    struct JOBOBJECT_BASIC_LIMIT_INFORMATION
    {
        public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit; public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize; public uint ActiveProcessLimit;
        public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct IO_COUNTERS { public ulong a, b, c, d, e, f; }
    [StructLayout(LayoutKind.Sequential)]
    struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
    {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation; public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit; public UIntPtr JobMemoryLimit; public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateJobObject(IntPtr a, string name);
    [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr job, int cls, ref JOBOBJECT_EXTENDED_LIMIT_INFORMATION info, uint len);
    [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);

    static IntPtr CreateKillOnCloseJob()
    {
        IntPtr job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero) return IntPtr.Zero;
        var info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        info.BasicLimitInformation.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        SetInformationJobObject(job, 9, ref info, (uint)Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION)));
        return job;
    }
}
