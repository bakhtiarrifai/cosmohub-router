# CosmosHub untuk Claude Code, Codex & GitHub Copilot

Panduan memakai saldo **CosmosHub** (dibayar dalam Rupiah) untuk menjalankan **Claude Code**, **OpenAI Codex**, dan **GitHub Copilot Chat**. Cara ini **tidak butuh** subscription Claude Pro/Max atau ChatGPT Plus. Semua pemakaian dipotong dari saldo CosmosHub.

> **Belum punya akun CosmosHub?** Daftar dan isi saldo lewat bot Telegram resminya memakai link referral ini: **https://t.me/CosmosStoreIDBot?start=ref_j86655**

Repo ini juga berisi **router fallback opsional** (khusus Windows). Router ini otomatis pindah ke model lain saat sebuah model sedang maintenance, dan pindah ke subscription saat saldo habis. Lihat [bagian 7](#7-opsional-router-fallback-otomatis-windows).

> Diuji pada 8 November 2026 dengan Claude Code 2.1.319, Codex CLI 0.167.0, dan VS Code 1.145.2 di Windows 11. Router, autostart, serta extension Claude Code dan Codex di VS Code juga diuji ulang setelah Windows di-restart. Daftar model CosmosHub bisa berubah sewaktu-waktu.
>
> Ini panduan komunitas, bukan dokumentasi resmi CosmosHub, Anthropic, OpenAI, atau GitHub.

---

## Bisa dipakai di mana?

| Aplikasi | Bisa pakai CosmosHub? | Keterangan |
|---|---|---|
| **Claude Code** (terminal) | ✅ Ya | [Bagian 1](#1-claude-code). Sudah diuji |
| **Codex CLI** (terminal) | ✅ Ya | [Bagian 2](#2-codex-openai). Sudah diuji, tanpa login ChatGPT |
| **GitHub Copilot Chat di VS Code** | ✅ Ya | [Bagian 3](#3-github-copilot-vs-code). Sudah diuji: chat dan agent mode |
| **Extension Claude Code & Codex di VS Code** | ✅ Ya | [Bagian 8](#8-opsional-extension-claude-code--codex-di-vs-code). Lewat router. Keduanya sudah diuji |
| **Aplikasi desktop GitHub Copilot** | ✅ Ya | [Bagian 9](#9-aplikasi-desktop-github-copilot--chatbox). Sudah diuji. Endpoint wajib diakhiri `/v1` |
| **Chatbox** (aplikasi chat mirip ChatGPT) | ✅ Ya | [Bagian 9](#9-aplikasi-desktop-github-copilot--chatbox) |
| **Copilot di github.com** (web) | ❌ Tidak | Tidak ada pengaturan endpoint sendiri |
| **claude.ai** (web) | ❌ Tidak | Hanya memakai model dan langganan Anthropic |
| **Claude Desktop** | ⚠️ Tidak disarankan | Ada mode *Third-party inference*, tapi dirancang untuk **model Claude** lewat gateway dan menggantikan login biasa. CosmosHub saat ini tidak menyediakan model Claude |
| **ChatGPT** (web & desktop) | ❌ Tidak | Hanya memakai model dan langganan OpenAI |

Ingin antarmuka chat seperti ChatGPT tapi memakai saldo CosmosHub? Pakai aplikasi chat yang mendukung *OpenAI-compatible API*, misalnya Chatbox ([bagian 9](#9-aplikasi-desktop-github-copilot--chatbox)), Cherry Studio, atau Open WebUI.

---

## 0. Yang perlu disiapkan

- **API key CosmosHub**. Ambil di dashboard CosmosHub, formatnya `sk-cos-...`. Belum punya akun? [Daftar di sini](https://t.me/CosmosStoreIDBot?start=ref_j86655).
- **Node.js 22 atau lebih baru**, untuk Codex. Unduh di https://nodejs.org.
- Terminal: PowerShell (Windows) atau Terminal (macOS/Linux).

**Endpoint CosmosHub:**

| Dipakai oleh | Format API | Alamat |
|---|---|---|
| Claude Code | Anthropic Messages | `https://api.cosmoshub.tech` |
| Codex | OpenAI Responses | `https://api.cosmoshub.tech/v1` |
| Copilot / aplikasi lain | OpenAI Chat Completions | `https://api.cosmoshub.tech/v1` |

---

## 1. Claude Code

### 1a. Install

Windows (PowerShell):
```powershell
irm https://claude.ai/install.ps1 | iex
```
macOS / Linux:
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows:** kalau muncul *"claude : The term 'claude' is not recognized..."*, tambahkan baris ini ke **Path** di Environment Variables (Start → *Edit environment variables for your account* → **Path** → **Edit** → **New**):

```
%USERPROFILE%\.local\bin
```

Klik OK, lalu buka PowerShell **baru**.

### 1b. Isi `settings.json`

Buka (atau buat) file ini:
- Windows: `%USERPROFILE%\.claude\settings.json`
- macOS / Linux: `~/.claude/settings.json`

Isi dengan contoh di bawah, lalu ganti `sk-cos-ISI-KEY-ANDA` dengan key Anda. Kalau file sudah berisi pengaturan lain, cukup tambahkan bagian `env` dan `model`.

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.cosmoshub.tech",
    "ANTHROPIC_AUTH_TOKEN": "sk-cos-ISI-KEY-ANDA",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "gpt-6.1-sol",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "gpt-6-sol",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash"
  },
  "hasCompletedOnboarding": true,
  "model": "opus"
}
```

Claude Code punya tiga "slot" model: **opus** (paling pintar), **sonnet** (seimbang), dan **haiku** (cepat dan murah, dipakai untuk tugas kecil di belakang layar). Setiap slot diarahkan ke model CosmosHub sesuai pengaturan di atas.

### 1c. Jalankan

```bash
claude
```

Ketik `/status` di dalam Claude Code. Bagian base URL harus menunjukkan `https://api.cosmoshub.tech`.

**Peringatan yang normal (abaikan saja):**
- *"Claude Code doesn't recognize the model ..."*: muncul karena nama model bukan model Claude. Claude Code menganggap konteksnya 200k token.
- *"claude.ai connectors are disabled ..."*: connector claude.ai (Gmail, Drive, dan lainnya) memang tidak aktif saat memakai API key pihak lain.

### 1d. Ganti model

- Sementara, dari dalam Claude Code: `/model gpt-6-sol`
- Permanen: ubah nilai `ANTHROPIC_DEFAULT_*_MODEL` di `settings.json`.

---

## 2. Codex (OpenAI)

### 2a. Install

```bash
npm install -g @openai/codex
```

### 2b. Simpan API key sebagai environment variable

Codex membaca key dari environment variable `COSMOSHUB_API_KEY`, jadi key tidak perlu ditulis di file config.

Windows (PowerShell). Key yang diketik tidak muncul di layar dan tidak tersimpan di riwayat:
```powershell
$k = Read-Host "CosmosHub API key"; [Environment]::SetEnvironmentVariable("COSMOSHUB_API_KEY", $k, "User"); Remove-Variable k
```
macOS / Linux (ganti `~/.zshrc` dengan `~/.bashrc` kalau memakai bash):
```bash
echo 'export COSMOSHUB_API_KEY="sk-cos-ISI-KEY-ANDA"' >> ~/.zshrc && source ~/.zshrc
```

Setelah itu, **buka terminal baru**.

### 2c. Isi `config.toml`

File:
- Windows: `%USERPROFILE%\.codex\config.toml`
- macOS / Linux: `~/.codex/config.toml`

```toml
model = "gpt-6.1-sol"
model_provider = "cosmoshub"

[model_providers.cosmoshub]
name = "CosmosHub"
base_url = "https://api.cosmoshub.tech/v1"
env_key = "COSMOSHUB_API_KEY"
wire_api = "responses"
```

### 2d. Jalankan

```bash
codex
```

Di header Codex harus tertulis `provider: cosmoshub`. **Codex tidak perlu login ChatGPT** untuk memakai provider ini.

Untuk sekali jalan dengan model lain: `codex -m kimi-k3.1-pro`

---

## 3. GitHub Copilot (VS Code)

Pakai fitur *Custom Endpoint* (BYOK, bring your own key) di Copilot Chat.

### 3a. Masukkan API key lewat wizard

1. Di VS Code, tekan `Ctrl+Shift+P` (Mac: `Cmd+Shift+P`). Kotak pencarian akan muncul di **bagian atas tengah** jendela. **Jangan** mengetik perintah ini di kotak chat Copilot.
2. Ketik `Manage Language Models`, lalu pilih **Chat: Manage Language Models**.
3. Klik **Add Models**, lalu pilih **Custom Endpoint**.
4. Isi nama grup `cosmoshub`, API key Anda, dan API type **Chat Completions**.
5. File `chatLanguageModels.json` akan terbuka. Key Anda tersimpan terenkripsi oleh VS Code, dan di file hanya muncul sebagai `${input:chat.lm.secret...}`.

### 3b. Isi daftar model

Di file `chatLanguageModels.json` tadi, ganti isi `"models": [ ... ]` dengan daftar ini. **Jangan ubah** baris `name`, `vendor`, `apiKey`, dan `apiType`.

```json
"models": [
  { "id": "gpt-6.1-sol",       "name": "GPT-6.1 Sol (CosmosHub)",       "url": "https://api.cosmoshub.tech/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "gpt-6-sol",         "name": "GPT-6 Sol (CosmosHub)",         "url": "https://api.cosmoshub.tech/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "kimi-k3.1-pro",     "name": "Kimi K3.1 Pro (CosmosHub)",     "url": "https://api.cosmoshub.tech/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "deepseek-v4-pro",   "name": "DeepSeek V4 Pro (CosmosHub)",   "url": "https://api.cosmoshub.tech/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "qwen-3.8-max",      "name": "Qwen 3.8 Max (CosmosHub)",      "url": "https://api.cosmoshub.tech/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "kimi-k2.7-code",    "name": "Kimi K2.7 Code (CosmosHub)",    "url": "https://api.cosmoshub.tech/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "glm-5.3",           "name": "GLM 5.3 (CosmosHub)",           "url": "https://api.cosmoshub.tech/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "deepseek-v4-flash", "name": "DeepSeek V4 Flash (CosmosHub)", "url": "https://api.cosmoshub.tech/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 }
]
```

Simpan file itu, lalu **restart VS Code**. Model berlabel "(CosmosHub)" akan muncul di model picker Copilot Chat. Kedelapan model ini sudah diuji mendukung tool calling, jadi bisa dipakai di **Agent mode**.

### 3c. Opsional: fitur pendukung

Tambahkan baris ini ke `settings.json` VS Code. Judul chat dan commit message otomatis akan ikut memakai model CosmosHub yang sedang dipilih:
```json
"chat.byokUtilityModelDefault": "mainAgent"
```

### Batasan

| Fitur Copilot | Dengan CosmosHub |
|---|---|
| Chat | ✅ Bisa |
| Agent mode | ✅ Bisa (model harus `toolCalling: true`) |
| Inline suggestion (saran kode saat mengetik) | ❌ Tetap butuh akun GitHub Copilot |
| Semantic search | ❌ Tidak bisa tanpa login GitHub |

- Kalau sebuah model sedang maintenance, pilih model lain di model picker. Copilot tidak pindah model secara otomatis.
- Akun **Copilot Business/Enterprise**: admin organisasi harus mengaktifkan policy *Bring Your Own Language Model Key in VS Code*.

---

## 4. Model yang tersedia (per 8 November 2026)

Cek daftar terbaru kapan saja:

Windows (PowerShell):
```powershell
(Invoke-RestMethod https://api.cosmoshub.tech/v1/models -Headers @{Authorization="Bearer $env:COSMOSHUB_API_KEY"}).data.id
```
macOS / Linux:
```bash
curl -s https://api.cosmoshub.tech/v1/models -H "Authorization: Bearer $COSMOSHUB_API_KEY"
```

| Kebutuhan | Pilihan model |
|---|---|
| Paling pintar (coding berat, perencanaan) | `gpt-6.1-sol`, `gpt-6-sol`, `kimi-k3.1-pro`, `deepseek-v4-pro`, `qwen-3.8-max` |
| Khusus coding | `kimi-k2.7-code`, `glm-5.3` |
| Cepat dan murah | `deepseek-v4-flash`, `glm-5.3-flash`, `gemini-3.8-flash`, `minimax-m3.1-flash` |

**Model Claude saat ini tidak tersedia di CosmosHub.** Kalau nanti tersedia lagi, namanya akan muncul di daftar `/v1/models`.

---

## 5. Kalau ada masalah

| Gejala | Artinya | Solusi |
|---|---|---|
| `401` / "Incorrect API key" | Key salah atau dicabut | Cek ulang key di dashboard CosmosHub |
| `404` "The model ... does not exist or is not available" | Model sedang maintenance atau tidak ada | Ganti ke model lain dari tabel di atas |
| `404` "Unknown endpoint: /v1/messages/count_tokens" | CosmosHub tidak menyediakan penghitung token | Normal, abaikan |
| Error saldo, kredit, atau quota | Saldo habis | Top-up di dashboard CosmosHub |
| Claude Code masih minta login | Onboarding belum dilewati | Pastikan ada `"hasCompletedOnboarding": true` di `settings.json` atau `~/.claude.json` |
| Windows: "The term 'claude' is not recognized as the name of a cmdlet..." | Folder `%USERPROFILE%\.local\bin` (tempat `claude.exe`) belum ada di PATH | Tambahkan `%USERPROFILE%\.local\bin` ke Path di Environment Variables ([bagian 1a](#1a-install)), lalu buka terminal **baru** |
| Codex: "Missing environment variable COSMOSHUB_API_KEY" | Terminal dibuka sebelum key disimpan | Tutup lalu buka terminal baru |
| VS Code: AI di chat balik bertanya "What would you like to do with language models?" | Perintah terketik di kotak chat | Tutup kotak itu, lalu pakai `Ctrl+Shift+P` |
| VS Code: model tidak muncul | Daftar model belum terbaca | Restart VS Code |
| Extension Claude Code masih memakai subscription | Wrapper memutuskan CosmosHub tidak bisa dipakai, atau setting belum terbaca | Baca alasannya di `~/.cosmohub/wrapper.log`, jalankan `check.ps1`, lalu restart VS Code |
| Extension Codex: "connection refused" / tidak bisa terhubung | Router tidak jalan (extension Codex tidak bisa menyalakannya sendiri) | Jalankan `check.ps1`. Kalau "Router process" gagal, jalankan ulang `install.ps1` atau ketik `cosmohub-status` di terminal |

---

## 6. Biaya dan keamanan

- **Ada biaya tersembunyi:** CosmosHub menambahkan sekitar **2.000 token** instruksi tersembunyi ke setiap request. Pertanyaan singkat pun tetap dihitung sekitar 2.000 token input. Pantau saldo di dashboard.
- **Jangan bagikan API key** di chat, screenshot, atau repository Git. File `settings.json` Claude Code berisi key, jadi jangan di-commit.
- Kalau key terlanjur bocor, **buat key baru** di dashboard CosmosHub dan hapus key yang lama.
- Dukungan resmi: hubungi admin CosmosHub lewat Telegram (tautan ada di dashboard).
- Isi saldo atau daftar akun baru: https://t.me/CosmosStoreIDBot?start=ref_j86655

---

## 7. Opsional: router fallback otomatis (Windows)

Untuk yang ingin:
- CosmosHub **otomatis pindah model** saat model yang diminta sedang maintenance, misalnya `gpt-6.1-sol` lalu `gpt-6-sol`, lalu `kimi-k3.1-pro`, dan seterusnya.
- **Otomatis kembali ke model Claude** begitu CosmosHub menyediakannya lagi.
- Kalau saldo habis, sesi **dilanjutkan di subscription** Claude atau ChatGPT. Ini hanya berguna kalau Anda punya subscription.

Router ini program Node.js kecil tanpa dependency. Ia hanya mendengarkan di `127.0.0.1:4141` (tidak bisa diakses dari komputer lain) dan dilindungi token lokal.

> Kalau memakai router, **jangan** isi `settings.json` (bagian 1b) dan `config.toml` (bagian 2c) dengan CosmosHub. Launcher router yang mengatur semuanya.

### Pasang

1. Install Node.js 22+, Claude Code, dan/atau Codex.
2. Clone repo ini, lalu jalankan installer-nya:
   ```powershell
   git clone https://github.com/bakhtiarrifai/cosmohub-router.git C:\Projects\cosmohub-router
   powershell -ExecutionPolicy Bypass -File C:\Projects\cosmohub-router\install.ps1
   ```
   Installer ini akan:
   - menanyakan API key kalau belum disimpan;
   - mengizinkan skrip lokal untuk user Anda;
   - memasang launcher di profil PowerShell;
   - memasang profil Codex;
   - mem-build wrapper VS Code;
   - membuat router otomatis jalan saat login Windows.
3. Buka **terminal baru**, lalu jalankan `C:\Projects\cosmohub-router\check.ps1`. Kalau semuanya `[OK]`, akan muncul **All good.** Jalankan lagi setelah restart Windows berikutnya. Baris "Router process" harus menunjukkan waktu Anda login, sebagai bukti router menyala otomatis.

> Kalau muncul *"running scripts is disabled on this system"*, berarti Anda memanggil `install.ps1` langsung. Pakai perintah lengkap di atas (dengan `-ExecutionPolicy Bypass`).

### Pakai

| Perintah | Fungsi |
|---|---|
| `claude` / `codex` | CosmosHub dulu (pindah model otomatis). Kalau CosmosHub tidak bisa dipakai, otomatis pakai subscription |
| `claude-sub` / `codex-sub` | Selalu pakai subscription |
| `cosmohub-status` | Kesehatan router dan log routing terbaru |
| `C:\Projects\cosmohub-router\check.ps1` | Cek lengkap semua bagian (berguna setelah restart Windows) |

Saat start akan muncul `[cosmohub] Using CosmosHub API (... models)`. Kalau saldo habis di tengah sesi, tool akan menampilkan pesan error. Ketik `/exit`, dan launcher akan melanjutkan percakapan yang sama di subscription (`claude --continue` / `codex resume --last`).

### Ubah urutan model

Edit `config.json`. Setiap slot berisi daftar model yang dicoba berurutan. Pola seperti `claude-opus*` berarti "model Claude Opus terbaru kalau tersedia".

```json
"opus":   ["claude-opus*",   "gpt-6.1-sol", "gpt-6-sol", "kimi-k3.1-pro", "deepseek-v4-pro", "qwen-3.8-max"],
"sonnet": ["claude-sonnet*", "gpt-6-sol", "kimi-k2.7-code", "glm-5.3", "deepseek-v4-pro"],
"haiku":  ["claude-haiku*",  "deepseek-v4-flash", "glm-5.3-flash", "gemini-3.8-flash"],
"codex":  ["gpt-6.1-sol", "gpt-6-sol", "gpt-5.6-sol", "kimi-k3.1-pro", "deepseek-v4-pro"]
```

Setelah mengubah `config.json`, hentikan proses router (`node.exe` yang menjalankan `router.js`). Router akan dijalankan ulang otomatis oleh `claude` atau `codex` berikutnya.

### Cara kerjanya

```
claude / codex  ──>  router 127.0.0.1:4141  ──>  CosmosHub
                      model mati (404/5xx/429)?  coba model berikutnya
                      saldo habis (401/402/403)? catat, lalu tool berhenti
launcher (cosmohub.ps1) ── setelah tool ditutup: saldo habis? lanjutkan di subscription
```

Login subscription **tidak pernah** dialirkan lewat router. Subscription hanya dipakai lewat aplikasi resminya, sesuai ketentuan Anthropic dan OpenAI.

---

## 8. Opsional: extension Claude Code & Codex di VS Code

Butuh router dari [bagian 7](#7-opsional-router-fallback-otomatis-windows) (jalankan `install.ps1` dulu).

### Extension Claude Code

`install.ps1` mem-build `bin\claude-hub.exe`, yaitu wrapper yang dipakai extension untuk menjalankan Claude. Wrapper ini memakai CosmosHub kalau router bisa dipakai, dan kembali ke subscription kalau tidak. Kalau router belum jalan, wrapper akan menyalakannya. Tambahkan ke `settings.json` VS Code:

```json
"claudeCode.claudeProcessWrapper": "C:\\Projects\\cosmohub-router\\bin\\claude-hub.exe"
```

Restart VS Code. Setiap keputusan wrapper (CosmosHub atau subscription) dicatat di `~/.cosmohub/wrapper.log`. Untuk sementara memakai subscription saja, hapus baris di atas dari `settings.json`.

### Extension Codex

Extension Codex selalu membaca `~/.codex/config.toml` utama. Tambahkan bagian ini di **paling atas** file tersebut:

```toml
model_provider = "cosmohub"

[model_providers.cosmohub]
name = "CosmosHub (local router)"
base_url = "http://127.0.0.1:4141/v1"
env_key = "COSMOHUB_ROUTER_TOKEN"
wire_api = "responses"
```

Restart VS Code. Dengan pengaturan ini, perintah `codex` di terminal juga lewat CosmosHub, sedangkan `codex-sub` tetap memakai subscription ChatGPT (`-c model_provider=openai`). Extension Codex **tidak** otomatis pindah ke subscription saat saldo habis. Kalau itu terjadi, hapus bagian di atas dari `config.toml`.

Extension Codex membawa engine Codex-nya sendiri, yang versinya bisa berbeda dari Codex CLI. Keduanya membaca `config.toml` yang sama. Untuk tugas kecil seperti membuat judul, extension memakai model ringan (misalnya `gpt-6-luna`). Model itu juga tersedia di CosmosHub, jadi ikut lewat router.

### Cara mengecek bahwa extension memakai CosmosHub

Kirim satu pesan di panel extension, lalu cek:

| Extension | Yang dicek | Tanda berhasil |
|---|---|---|
| Claude Code | `check.ps1`, baris "Last VS Code Claude launch" (atau `~/.cosmohub/wrapper.log`) | Diawali `cosmoshub ::` |
| Claude Code | `~/.cosmohub/router.log` | Ada baris `/v1/messages hub-opus -> ... 200` |
| Codex | `~/.cosmohub/router.log` | Ada baris `/v1/responses ... 200` |
| Codex | Baris pertama file sesi terbaru di `~/.codex/sessions/` | Berisi `"originator":"codex_vscode"` dan `"model_provider":"cosmohub"` |

---

## 9. Aplikasi desktop GitHub Copilot & Chatbox

Keduanya bisa diinstall lewat winget dan dihubungkan **langsung** ke CosmosHub, tanpa router:

```powershell
winget install --id GitHub.CopilotApp -e
winget install --id Bin-Huang.Chatbox -e
```

### Aplikasi desktop GitHub Copilot

1. Buka aplikasi GitHub Copilot dan login dengan akun GitHub.
2. Buka **Settings → Model Providers**, lalu tambahkan provider **OpenAI-compatible**.
3. Isi endpoint **`https://api.cosmoshub.tech/v1`** dan API key CosmosHub Anda. Bagian **`/v1` wajib ada**. Tanpa itu, aplikasi tidak bisa terhubung ke model CosmosHub.
4. Saat memulai sesi, pilih model CosmosHub di model picker, misalnya `gpt-6.1-sol`.

Akun Copilot Business/Enterprise: admin harus mengaktifkan policy *Enable custom models (BYOK)*.

### Chatbox

1. Buka Chatbox. Kalau di layar pembuka diminta lisensi, pilih opsi untuk memakai **API key sendiri**. Lisensi hanya untuk layanan berbayar "Chatbox AI". Lalu masuk ke **Settings → Model Provider**. Tambahkan provider baru bertipe **OpenAI API Compatible**.
2. Isi:
   - Name: `CosmosHub`
   - API Host: `https://api.cosmoshub.tech/v1` (dengan `/v1`, supaya tombol **Fetch** bisa mengambil daftar model dari `/v1/models`)
   - API Path: `/chat/completions`
   - API Key: key CosmosHub Anda
3. Klik **Fetch** untuk mengambil daftar model, atau tambahkan manual: `gpt-6.1-sol`, `kimi-k3.1-pro`, `deepseek-v4-flash`, dan seterusnya.
4. Pilih model CosmosHub di percakapan baru.

Nama menu bisa sedikit berbeda antar versi aplikasi.

---

## Lisensi

MIT. Lihat [LICENSE](LICENSE).
