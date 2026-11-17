# CosmosHub untuk / for Claude Code, Codex & GitHub Copilot

**[Bahasa Indonesia](#bahasa-indonesia)** · **[English](#english)**

## Bahasa Indonesia

Panduan memakai saldo **CosmosHub** (dibayar dalam Rupiah) untuk menjalankan **Claude Code**, **OpenAI Codex**, dan **GitHub Copilot Chat**. Cara ini **tidak butuh** subscription Claude Pro/Max atau ChatGPT Plus. Semua pemakaian dipotong dari saldo CosmosHub.

> **Belum punya akun CosmosHub?** Daftar lewat link referral ini: **https://cosmosin.io/r/34D5W2DC**, lalu isi saldo melalui platform tersebut.

Repo ini juga berisi **router fallback opsional** (khusus Windows). Router ini otomatis pindah ke model lain saat sebuah model sedang maintenance, dan pindah ke subscription saat saldo habis. Lihat [bagian 7](#7-opsional-router-fallback-otomatis-windows).

> **Migrasi API:** Base URL sekarang `https://api.cosmosin.io`. Pengguna Telegram lama perlu membuka **https://cosmosin.io**, daftar/login memakai Email atau Google, lalu masuk ke **Settings → Connect Telegram** dan tautkan akun Telegram yang sama. Setelah ditautkan, saldo dan API key lama aktif kembali di web. Ganti konfigurasi endpoint lama dengan alamat di panduan ini; bagi pengguna router, update repo, hentikan proses `router.js`, lalu jalankan lagi `claude` atau `codex`.

> Diuji pada 8 November 2026 dengan Claude Code 2.1.319, Codex CLI 0.167.0, dan VS Code 1.145.2 di Windows 11. Router, autostart, serta extension Claude Code dan Codex di VS Code juga diuji ulang setelah Windows di-restart. Daftar model CosmosHub bisa berubah sewaktu-waktu.
>
> Ini panduan komunitas, bukan dokumentasi resmi CosmosHub, Anthropic, OpenAI, atau GitHub.

---

### Bisa dipakai di mana?

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

### 0. Yang perlu disiapkan

- **API key CosmosHub**. Ambil di dashboard **https://cosmosin.io**. Pengguna Telegram lama harus menautkan akun lewat **Settings → Connect Telegram** terlebih dahulu.
- **Node.js 22 atau lebih baru**, untuk Codex. Unduh di https://nodejs.org.
- Terminal: PowerShell (Windows) atau Terminal (macOS/Linux).

**Endpoint CosmosHub:**

| Dipakai oleh | Format API | Alamat |
|---|---|---|
| Claude Code | Anthropic Messages | `https://api.cosmosin.io` |
| Codex | OpenAI Responses | `https://api.cosmosin.io/v1` |
| Copilot / aplikasi lain | OpenAI Chat Completions | `https://api.cosmosin.io/v1` |

---

### 1. Claude Code

#### 1a. Install

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

#### 1b. Isi `settings.json`

Buka (atau buat) file ini:
- Windows: `%USERPROFILE%\.claude\settings.json`
- macOS / Linux: `~/.claude/settings.json`

Isi dengan contoh di bawah, lalu ganti `sk-cos-ISI-KEY-ANDA` dengan key Anda. Kalau file sudah berisi pengaturan lain, cukup tambahkan bagian `env` dan `model`.

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.cosmosin.io",
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

#### 1c. Jalankan

```bash
claude
```

Ketik `/status` di dalam Claude Code. Bagian base URL harus menunjukkan `https://api.cosmosin.io`.

**Peringatan yang normal (abaikan saja):**
- *"Claude Code doesn't recognize the model ..."*: muncul karena nama model bukan model Claude. Claude Code menganggap konteksnya 200k token.
- *"claude.ai connectors are disabled ..."*: connector claude.ai (Gmail, Drive, dan lainnya) memang tidak aktif saat memakai API key pihak lain.

#### 1d. Ganti model

- Sementara, dari dalam Claude Code: `/model gpt-6-sol`
- Permanen: ubah nilai `ANTHROPIC_DEFAULT_*_MODEL` di `settings.json`.

---

### 2. Codex (OpenAI)

#### 2a. Install

```bash
npm install -g @openai/codex
```

#### 2b. Simpan API key sebagai environment variable

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

#### 2c. Isi `config.toml`

File:
- Windows: `%USERPROFILE%\.codex\config.toml`
- macOS / Linux: `~/.codex/config.toml`

```toml
model = "gpt-6.1-sol"
model_provider = "cosmoshub"

[model_providers.cosmoshub]
name = "CosmosHub"
base_url = "https://api.cosmosin.io/v1"
env_key = "COSMOSHUB_API_KEY"
wire_api = "responses"
```

#### 2d. Jalankan

```bash
codex
```

Di header Codex harus tertulis `provider: cosmoshub`. **Codex tidak perlu login ChatGPT** untuk memakai provider ini.

Untuk sekali jalan dengan model lain: `codex -m kimi-k3.1-pro`

---

### 3. GitHub Copilot (VS Code)

Pakai fitur *Custom Endpoint* (BYOK, bring your own key) di Copilot Chat.

#### 3a. Masukkan API key lewat wizard

1. Di VS Code, tekan `Ctrl+Shift+P` (Mac: `Cmd+Shift+P`). Kotak pencarian akan muncul di **bagian atas tengah** jendela. **Jangan** mengetik perintah ini di kotak chat Copilot.
2. Ketik `Manage Language Models`, lalu pilih **Chat: Manage Language Models**.
3. Klik **Add Models**, lalu pilih **Custom Endpoint**.
4. Isi nama grup `cosmoshub`, API key Anda, dan API type **Chat Completions**.
5. File `chatLanguageModels.json` akan terbuka. Key Anda tersimpan terenkripsi oleh VS Code, dan di file hanya muncul sebagai `${input:chat.lm.secret...}`.

#### 3b. Isi daftar model

Di file `chatLanguageModels.json` tadi, ganti isi `"models": [ ... ]` dengan daftar ini. **Jangan ubah** baris `name`, `vendor`, `apiKey`, dan `apiType`.

```json
"models": [
  { "id": "gpt-6.1-sol",       "name": "GPT-6.1 Sol (CosmosHub)",       "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "gpt-6-sol",         "name": "GPT-6 Sol (CosmosHub)",         "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "kimi-k3.1-pro",     "name": "Kimi K3.1 Pro (CosmosHub)",     "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "deepseek-v4-pro",   "name": "DeepSeek V4 Pro (CosmosHub)",   "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "qwen-3.8-max",      "name": "Qwen 3.8 Max (CosmosHub)",      "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "kimi-k2.7-code",    "name": "Kimi K2.7 Code (CosmosHub)",    "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "glm-5.3",           "name": "GLM 5.3 (CosmosHub)",           "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "deepseek-v4-flash", "name": "DeepSeek V4 Flash (CosmosHub)", "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 }
]
```

Simpan file itu, lalu **restart VS Code**. Model berlabel "(CosmosHub)" akan muncul di model picker Copilot Chat. Kedelapan model ini sudah diuji mendukung tool calling, jadi bisa dipakai di **Agent mode**.

#### 3c. Opsional: fitur pendukung

Tambahkan baris ini ke `settings.json` VS Code. Judul chat dan commit message otomatis akan ikut memakai model CosmosHub yang sedang dipilih:
```json
"chat.byokUtilityModelDefault": "mainAgent"
```

#### Batasan

| Fitur Copilot | Dengan CosmosHub |
|---|---|
| Chat | ✅ Bisa |
| Agent mode | ✅ Bisa (model harus `toolCalling: true`) |
| Inline suggestion (saran kode saat mengetik) | ❌ Tetap butuh akun GitHub Copilot |
| Semantic search | ❌ Tidak bisa tanpa login GitHub |

- Kalau sebuah model sedang maintenance, pilih model lain di model picker. Copilot tidak pindah model secara otomatis.
- Akun **Copilot Business/Enterprise**: admin organisasi harus mengaktifkan policy *Bring Your Own Language Model Key in VS Code*.

---

### 4. Model yang tersedia (per 8 November 2026)

Cek daftar terbaru kapan saja:

Windows (PowerShell):
```powershell
(Invoke-RestMethod https://api.cosmosin.io/v1/models -Headers @{Authorization="Bearer $env:COSMOSHUB_API_KEY"}).data.id
```
macOS / Linux:
```bash
curl -s https://api.cosmosin.io/v1/models -H "Authorization: Bearer $COSMOSHUB_API_KEY"
```

| Kebutuhan | Pilihan model |
|---|---|
| Paling pintar (coding berat, perencanaan) | `gpt-6.1-sol`, `gpt-6-sol`, `kimi-k3.1-pro`, `deepseek-v4-pro`, `qwen-3.8-max` |
| Khusus coding | `kimi-k2.7-code`, `glm-5.3` |
| Cepat dan murah | `deepseek-v4-flash`, `glm-5.3-flash`, `gemini-3.8-flash`, `minimax-m3.1-flash` |

**Model Claude saat ini tidak tersedia di CosmosHub.** Kalau nanti tersedia lagi, namanya akan muncul di daftar `/v1/models`.

---

### 5. Kalau ada masalah

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

### 6. Biaya dan keamanan

- **Ada biaya tersembunyi:** CosmosHub menambahkan sekitar **2.000 token** instruksi tersembunyi ke setiap request. Pertanyaan singkat pun tetap dihitung sekitar 2.000 token input. Pantau saldo di dashboard.
- **Jangan bagikan API key** di chat, screenshot, atau repository Git. File `settings.json` Claude Code berisi key, jadi jangan di-commit.
- Kalau key terlanjur bocor, **buat key baru** di dashboard CosmosHub dan hapus key yang lama.
- Dukungan resmi: hubungi admin CosmosHub lewat Telegram (tautan ada di dashboard).
- Daftar akun baru (link referral): **https://cosmosin.io/r/34D5W2DC**. Isi saldo: **https://cosmosin.io**.

---

### 7. Opsional: router fallback otomatis (Windows)

Untuk yang ingin:
- CosmosHub **otomatis pindah model** saat model yang diminta sedang maintenance, misalnya `gpt-6.1-sol` lalu `gpt-6-sol`, lalu `kimi-k3.1-pro`, dan seterusnya.
- **Otomatis kembali ke model Claude** begitu CosmosHub menyediakannya lagi.
- Kalau saldo habis, sesi **dilanjutkan di subscription** Claude atau ChatGPT. Ini hanya berguna kalau Anda punya subscription.

Router ini program Node.js kecil tanpa dependency. Ia hanya mendengarkan di `127.0.0.1:4141` (tidak bisa diakses dari komputer lain) dan dilindungi token lokal.

> Kalau memakai router, **jangan** isi `settings.json` (bagian 1b) dan `config.toml` (bagian 2c) dengan CosmosHub. Launcher router yang mengatur semuanya.

#### Pasang

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

#### Pakai

| Perintah | Fungsi |
|---|---|
| `claude` / `codex` | CosmosHub dulu (pindah model otomatis). Kalau CosmosHub tidak bisa dipakai, otomatis pakai subscription |
| `claude-sub` / `codex-sub` | Selalu pakai subscription |
| `cosmohub-status` | Kesehatan router, model tujuan berikutnya, model terakhir yang dipakai, dan log routing |
| `cosmohub-model` | Lihat mode auto/manual dan model per slot |
| `cosmohub-model -List` | Daftar ID model yang tersedia dari CosmosHub |
| `cosmohub-model -Watch` | Pantau perubahan model hasil routing di terminal terpisah (Ctrl+C untuk berhenti) |
| `cosmohub-model opus kimi-k3.1-pro` | Kunci slot opus ke model tersebut, tanpa fallback diam-diam |
| `cosmohub-model opus auto` | Kembalikan slot opus ke fallback otomatis |
| `C:\Projects\cosmohub-router\check.ps1` | Cek lengkap semua bagian (berguna setelah restart Windows) |

Saat start akan muncul `[cosmohub] Using CosmosHub API (... models)`. Kalau saldo habis di tengah sesi, tool akan menampilkan pesan error. Ketik `/exit`, dan launcher akan melanjutkan percakapan yang sama di subscription (`claude --continue` / `codex resume --last`).

#### Lihat dan pilih model secara manual

Setiap launcher menampilkan tabel **Next request** (prediksi tujuan berikutnya), **Last used** (model tujuan request generasi terakhir yang diterima upstream), dan waktunya. Nama slot/model di header Claude Code bisa tetap berupa alias; lihat `cosmohub-model` untuk tujuan routing sebenarnya. Router tidak mengklaim mengetahui model internal di balik alias milik CosmosHub.

```powershell
# Muat fungsi baru di terminal yang sudah terbuka setelah update repo:
. C:\Projects\cosmohub-router\cosmohub.ps1

cosmohub-model                         # status seluruh slot
cosmohub-model -List                   # daftar ID model
cosmohub-model opus kimi-k3.1-pro       # pilihan manual untuk slot opus
cosmohub-model sonnet deepseek-v4-pro   # slot sonnet bisa berbeda
cosmohub-model codex gpt-6-sol          # pilihan untuk Codex
cosmohub-model opus auto               # kembali ke fallback otomatis
```

Pilihan disimpan di `~/.cosmohub/model-selection.json` dan tetap ada setelah router/komputer restart. Berlaku **global per slot** untuk request berikutnya, termasuk sesi terminal dan extension yang sedang terbuka; request yang sudah berjalan tidak diubah. Mode manual tidak pindah model saat model gagal: error dikembalikan supaya pilihan tidak diam-diam berubah. Penanganan saldo habis tetap berlaku.

Untuk memilih model tepat **hanya dalam sesi Claude Code**, ketik `/model hub-model/kimi-k3.1-pro`. Prefix `hub-model/` mengunci ID tanpa fallback dan mengabaikan pilihan global per slot. Kembali ke `/model opus` untuk mengikuti pengaturan slot lagi.

Saat bekerja, buka terminal kedua dan jalankan `cosmohub-model -Watch` untuk melihat tujuan routing terbaru. Watch membaca status setiap detik, bukan semua event: request yang sangat berdekatan dapat terlewat. **Last used** bersifat global, bukan status khusus satu percakapan, dan baru tercatat saat upstream menerima request generasi (bukan jaminan stream selesai). Tugas latar belakang juga bisa mengubahnya. Setelah router restart, status terakhir kosong sampai ada request baru. Respons generasi menyertakan header `x-cosmohub-model` dan `x-cosmohub-mode`; endpoint lokal `GET /router/models` serta `POST /router/models` (`{"slot":"opus","model":"kimi-k3.1-pro"}` atau `model: null` untuk auto) memerlukan token router.

Jika router masih menjalankan versi lama, hentikan **hanya proses Node yang menjalankan `cosmohub-router\router.js`** saat tidak ada generasi berjalan, lalu jalankan `cosmohub-status` untuk menyalakan versi baru. Tidak perlu menjalankan ulang installer atau membangun wrapper untuk fitur ini.

#### Ubah urutan model

Edit `config.json`. Setiap slot berisi daftar model yang dicoba berurutan. Pola seperti `claude-opus*` berarti "model Claude Opus terbaru kalau tersedia".

```json
"opus":   ["claude-opus*",   "gpt-6.1-sol", "gpt-6-sol", "kimi-k3.1-pro", "deepseek-v4-pro", "qwen-3.8-max"],
"sonnet": ["claude-sonnet*", "gpt-6-sol", "kimi-k2.7-code", "glm-5.3", "deepseek-v4-pro"],
"haiku":  ["claude-haiku*",  "deepseek-v4-flash", "glm-5.3-flash", "gemini-3.8-flash"],
"codex":  ["gpt-6.1-sol", "gpt-6-sol", "gpt-5.6-sol", "kimi-k3.1-pro", "deepseek-v4-pro"]
```

Setelah mengubah `config.json`, hentikan proses router (`node.exe` yang menjalankan `router.js`). Router akan dijalankan ulang otomatis oleh `claude` atau `codex` berikutnya.

#### Cara kerjanya

```
claude / codex  ──>  router 127.0.0.1:4141  ──>  CosmosHub
                      model mati (404/5xx/429)?  coba model berikutnya
                      saldo habis (401/402/403)? catat, lalu tool berhenti
launcher (cosmohub.ps1) ── setelah tool ditutup: saldo habis? lanjutkan di subscription
```

Login subscription **tidak pernah** dialirkan lewat router. Subscription hanya dipakai lewat aplikasi resminya, sesuai ketentuan Anthropic dan OpenAI.

---

### 8. Opsional: extension Claude Code & Codex di VS Code

Butuh router dari [bagian 7](#7-opsional-router-fallback-otomatis-windows) (jalankan `install.ps1` dulu).

#### Extension Claude Code

`install.ps1` mem-build `bin\claude-hub.exe`, yaitu wrapper yang dipakai extension untuk menjalankan Claude. Wrapper ini memakai CosmosHub kalau router bisa dipakai, dan kembali ke subscription kalau tidak. Kalau router belum jalan, wrapper akan menyalakannya. Tambahkan ke `settings.json` VS Code:

```json
"claudeCode.claudeProcessWrapper": "C:\\Projects\\cosmohub-router\\bin\\claude-hub.exe"
```

Restart VS Code. Setiap keputusan wrapper (CosmosHub atau subscription) dicatat di `~/.cosmohub/wrapper.log`. Untuk sementara memakai subscription saja, hapus baris di atas dari `settings.json`.

#### Extension Codex

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

#### Cara mengecek bahwa extension memakai CosmosHub

Kirim satu pesan di panel extension, lalu cek:

| Extension | Yang dicek | Tanda berhasil |
|---|---|---|
| Claude Code | `check.ps1`, baris "Last VS Code Claude launch" (atau `~/.cosmohub/wrapper.log`) | Diawali `cosmoshub ::` |
| Claude Code | `~/.cosmohub/router.log` | Ada baris `/v1/messages claude-opus-5-5 -> ... 200` |
| Codex | `~/.cosmohub/router.log` | Ada baris `/v1/responses ... 200` |
| Codex | Baris pertama file sesi terbaru di `~/.codex/sessions/` | Berisi `"originator":"codex_vscode"` dan `"model_provider":"cosmohub"` |

---

### 9. Aplikasi desktop GitHub Copilot & Chatbox

Keduanya bisa diinstall lewat winget dan dihubungkan **langsung** ke CosmosHub, tanpa router:

```powershell
winget install --id GitHub.CopilotApp -e
winget install --id Bin-Huang.Chatbox -e
```

#### Aplikasi desktop GitHub Copilot

1. Buka aplikasi GitHub Copilot dan login dengan akun GitHub.
2. Buka **Settings → Model Providers**, lalu tambahkan provider **OpenAI-compatible**.
3. Isi endpoint **`https://api.cosmosin.io/v1`** dan API key CosmosHub Anda. Bagian **`/v1` wajib ada**. Tanpa itu, aplikasi tidak bisa terhubung ke model CosmosHub.
4. Saat memulai sesi, pilih model CosmosHub di model picker, misalnya `gpt-6.1-sol`.

Akun Copilot Business/Enterprise: admin harus mengaktifkan policy *Enable custom models (BYOK)*.

#### Chatbox

1. Buka Chatbox. Kalau di layar pembuka diminta lisensi, pilih opsi untuk memakai **API key sendiri**. Lisensi hanya untuk layanan berbayar "Chatbox AI". Lalu masuk ke **Settings → Model Provider**. Tambahkan provider baru bertipe **OpenAI API Compatible**.
2. Isi:
   - Name: `CosmosHub`
   - API Host: `https://api.cosmosin.io` (tanpa `/v1`)
   - API Path: `/v1/chat/completions`
   - API Key: key CosmosHub Anda
3. Klik **Fetch** untuk mengambil daftar model, atau tambahkan manual: `gpt-6.1-sol`, `kimi-k3.1-pro`, `deepseek-v4-flash`, dan seterusnya.
4. Pilih model CosmosHub di percakapan baru.

Nama menu bisa sedikit berbeda antar versi aplikasi.

---

### Lisensi

MIT. Lihat [LICENSE](LICENSE).

---

## English

A guide to using a **CosmosHub** balance (paid in Rupiah) to run **Claude Code**, **OpenAI Codex** and **GitHub Copilot Chat**. It does **not** need a Claude Pro/Max or ChatGPT Plus subscription. All usage is deducted from your CosmosHub balance.

> **No CosmosHub account yet?** Sign up with this referral link: **https://cosmosin.io/r/34D5W2DC**, then top up your balance on the platform.

This repo also contains an **optional fallback router** (Windows only). It automatically moves to another model while a model is under maintenance, and moves to your subscription when the balance runs out. See [section 7](#7-optional-automatic-fallback-router-windows).

> **API migration:** the base URL is now `https://api.cosmosin.io`. Existing Telegram users need to open **https://cosmosin.io**, sign up / sign in with Email or Google, then go to **Settings → Connect Telegram** and link the same Telegram account. Once linked, the old balance and API keys work again on the web. Replace the old endpoint configuration with the addresses in this guide; router users should update the repo, stop the `router.js` process, then run `claude` or `codex` again.

> Tested on 8 November 2026 with Claude Code 2.1.319, Codex CLI 0.167.0 and VS Code 1.145.2 on Windows 11. The router, autostart, and the Claude Code and Codex extensions in VS Code were tested again after a Windows restart. The CosmosHub model list can change at any time.
>
> This is a community guide, not official documentation from CosmosHub, Anthropic, OpenAI or GitHub.

---

### Where can I use it?

| App | Works with CosmosHub? | Notes |
|---|---|---|
| **Claude Code** (terminal) | ✅ Yes | [Section 1](#1-claude-code-1). Tested |
| **Codex CLI** (terminal) | ✅ Yes | [Section 2](#2-codex-openai-1). Tested, no ChatGPT login |
| **GitHub Copilot Chat in VS Code** | ✅ Yes | [Section 3](#3-github-copilot-vs-code-1). Tested: chat and agent mode |
| **Claude Code & Codex extensions in VS Code** | ✅ Yes | [Section 8](#8-optional-claude-code--codex-extensions-in-vs-code). Through the router. Both tested |
| **GitHub Copilot desktop app** | ✅ Yes | [Section 9](#9-github-copilot-desktop-app--chatbox). Tested. The endpoint must end in `/v1` |
| **Chatbox** (ChatGPT-like chat app) | ✅ Yes | [Section 9](#9-github-copilot-desktop-app--chatbox) |
| **Copilot on github.com** (web) | ❌ No | No setting for a custom endpoint |
| **claude.ai** (web) | ❌ No | Uses only Anthropic's models and subscriptions |
| **Claude Desktop** | ⚠️ Not recommended | It has a *Third-party inference* mode, but it is designed for **Claude models** through a gateway and replaces the normal login. CosmosHub currently offers no Claude models |
| **ChatGPT** (web & desktop) | ❌ No | Uses only OpenAI's models and subscriptions |

Want a ChatGPT-like chat interface on your CosmosHub balance? Use a chat app that supports an *OpenAI-compatible API*, such as Chatbox ([section 9](#9-github-copilot-desktop-app--chatbox)), Cherry Studio or Open WebUI.

---

### 0. What you need

- **A CosmosHub API key.** Get it from the **https://cosmosin.io** dashboard. Existing Telegram users must link their account first under **Settings → Connect Telegram**.
- **Node.js 22 or newer**, for Codex. Download it from https://nodejs.org.
- A terminal: PowerShell (Windows) or Terminal (macOS/Linux).

**CosmosHub endpoints:**

| Used by | API format | Address |
|---|---|---|
| Claude Code | Anthropic Messages | `https://api.cosmosin.io` |
| Codex | OpenAI Responses | `https://api.cosmosin.io/v1` |
| Copilot / other apps | OpenAI Chat Completions | `https://api.cosmosin.io/v1` |

---

### 1. Claude Code

#### 1a. Install

Windows (PowerShell):
```powershell
irm https://claude.ai/install.ps1 | iex
```
macOS / Linux:
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows:** if you see *"claude : The term 'claude' is not recognized..."*, add this line to **Path** in Environment Variables (Start → *Edit environment variables for your account* → **Path** → **Edit** → **New**):

```
%USERPROFILE%\.local\bin
```

Click OK, then open a **new** PowerShell.

#### 1b. Fill in `settings.json`

Open (or create) this file:
- Windows: `%USERPROFILE%\.claude\settings.json`
- macOS / Linux: `~/.claude/settings.json`

Fill it with the example below and replace `sk-cos-ISI-KEY-ANDA` with your key. If the file already has other settings, just add the `env` and `model` parts.

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.cosmosin.io",
    "ANTHROPIC_AUTH_TOKEN": "sk-cos-ISI-KEY-ANDA",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "gpt-6.1-sol",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "gpt-6-sol",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash"
  },
  "hasCompletedOnboarding": true,
  "model": "opus"
}
```

Claude Code has three model "slots": **opus** (smartest), **sonnet** (balanced) and **haiku** (fast and cheap, used for small background tasks). Each slot points to the CosmosHub model set above.

#### 1c. Run

```bash
claude
```

Type `/status` inside Claude Code. The base URL should show `https://api.cosmosin.io`.

**Normal warnings (ignore them):**
- *"Claude Code doesn't recognize the model ..."*: shown because the model name is not a Claude model. Claude Code assumes a 200k-token context.
- *"claude.ai connectors are disabled ..."*: claude.ai connectors (Gmail, Drive and others) are off while a third-party API key is in use.

#### 1d. Change the model

- For now, from inside Claude Code: `/model gpt-6-sol`
- Permanently: change the `ANTHROPIC_DEFAULT_*_MODEL` values in `settings.json`.

---

### 2. Codex (OpenAI)

#### 2a. Install

```bash
npm install -g @openai/codex
```

#### 2b. Save the API key as an environment variable

Codex reads the key from the `COSMOSHUB_API_KEY` environment variable, so the key never has to be written into the config file.

Windows (PowerShell). The key you type is not shown on screen and is not saved in the history:
```powershell
$k = Read-Host "CosmosHub API key"; [Environment]::SetEnvironmentVariable("COSMOSHUB_API_KEY", $k, "User"); Remove-Variable k
```
macOS / Linux (replace `~/.zshrc` with `~/.bashrc` if you use bash):
```bash
echo 'export COSMOSHUB_API_KEY="sk-cos-ISI-KEY-ANDA"' >> ~/.zshrc && source ~/.zshrc
```

Then **open a new terminal**.

#### 2c. Fill in `config.toml`

File:
- Windows: `%USERPROFILE%\.codex\config.toml`
- macOS / Linux: `~/.codex/config.toml`

```toml
model = "gpt-6.1-sol"
model_provider = "cosmoshub"

[model_providers.cosmoshub]
name = "CosmosHub"
base_url = "https://api.cosmosin.io/v1"
env_key = "COSMOSHUB_API_KEY"
wire_api = "responses"
```

#### 2d. Run

```bash
codex
```

The Codex header should say `provider: cosmoshub`. **Codex does not need a ChatGPT login** for this provider.

For a single run with another model: `codex -m kimi-k3.1-pro`

---

### 3. GitHub Copilot (VS Code)

Use the *Custom Endpoint* feature (BYOK, bring your own key) in Copilot Chat.

#### 3a. Enter the API key through the wizard

1. In VS Code, press `Ctrl+Shift+P` (Mac: `Cmd+Shift+P`). A search box appears at the **top center** of the window. Do **not** type this command into the Copilot chat box.
2. Type `Manage Language Models`, then choose **Chat: Manage Language Models**.
3. Click **Add Models**, then choose **Custom Endpoint**.
4. Enter the group name `cosmoshub`, your API key, and API type **Chat Completions**.
5. The file `chatLanguageModels.json` opens. VS Code stores your key encrypted; in the file it only appears as `${input:chat.lm.secret...}`.

#### 3b. Fill in the model list

In that `chatLanguageModels.json` file, replace the contents of `"models": [ ... ]` with this list. **Do not change** the `name`, `vendor`, `apiKey` and `apiType` lines.

```json
"models": [
  { "id": "gpt-6.1-sol",       "name": "GPT-6.1 Sol (CosmosHub)",       "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "gpt-6-sol",         "name": "GPT-6 Sol (CosmosHub)",         "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "kimi-k3.1-pro",     "name": "Kimi K3.1 Pro (CosmosHub)",     "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "deepseek-v4-pro",   "name": "DeepSeek V4 Pro (CosmosHub)",   "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "qwen-3.8-max",      "name": "Qwen 3.8 Max (CosmosHub)",      "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "kimi-k2.7-code",    "name": "Kimi K2.7 Code (CosmosHub)",    "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "glm-5.3",           "name": "GLM 5.3 (CosmosHub)",           "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 },
  { "id": "deepseek-v4-flash", "name": "DeepSeek V4 Flash (CosmosHub)", "url": "https://api.cosmosin.io/v1/chat/completions", "toolCalling": true, "vision": false, "maxInputTokens": 128000, "maxOutputTokens": 16000 }
]
```

Save the file, then **restart VS Code**. Models labelled "(CosmosHub)" appear in the Copilot Chat model picker. All eight models were tested with tool calling, so they work in **Agent mode**.

#### 3c. Optional: supporting features

Add this line to VS Code's `settings.json`. Chat titles and automatic commit messages then use the CosmosHub model that is currently selected:
```json
"chat.byokUtilityModelDefault": "mainAgent"
```

#### Limits

| Copilot feature | With CosmosHub |
|---|---|
| Chat | ✅ Works |
| Agent mode | ✅ Works (the model must have `toolCalling: true`) |
| Inline suggestions (code suggestions while typing) | ❌ Still needs a GitHub Copilot account |
| Semantic search | ❌ Not without a GitHub login |

- If a model is under maintenance, pick another one in the model picker. Copilot does not switch models automatically.
- **Copilot Business/Enterprise** accounts: an organization admin must enable the *Bring Your Own Language Model Key in VS Code* policy.

---

### 4. Available models (as of 8 November 2026)

Check the current list at any time:

Windows (PowerShell):
```powershell
(Invoke-RestMethod https://api.cosmosin.io/v1/models -Headers @{Authorization="Bearer $env:COSMOSHUB_API_KEY"}).data.id
```
macOS / Linux:
```bash
curl -s https://api.cosmosin.io/v1/models -H "Authorization: Bearer $COSMOSHUB_API_KEY"
```

| Need | Models |
|---|---|
| Smartest (heavy coding, planning) | `gpt-6.1-sol`, `gpt-6-sol`, `kimi-k3.1-pro`, `deepseek-v4-pro`, `qwen-3.8-max` |
| Coding-focused | `kimi-k2.7-code`, `glm-5.3` |
| Fast and cheap | `deepseek-v4-flash`, `glm-5.3-flash`, `gemini-3.8-flash`, `minimax-m3.1-flash` |

**Claude models are currently not available on CosmosHub.** If they come back, their names will appear in the `/v1/models` list.

---

### 5. Troubleshooting

| Symptom | Meaning | Fix |
|---|---|---|
| `401` / "Incorrect API key" | The key is wrong or revoked | Check the key in the CosmosHub dashboard |
| `404` "The model ... does not exist or is not available" | The model is under maintenance or does not exist | Switch to another model from the table above |
| `404` "Unknown endpoint: /v1/messages/count_tokens" | CosmosHub does not offer token counting | Normal, ignore it |
| Balance, credit or quota error | The balance is used up | Top up in the CosmosHub dashboard |
| Claude Code still asks you to log in | Onboarding was not skipped | Make sure `"hasCompletedOnboarding": true` is in `settings.json` or `~/.claude.json` |
| Windows: "The term 'claude' is not recognized as the name of a cmdlet..." | The `%USERPROFILE%\.local\bin` folder (where `claude.exe` lives) is not on PATH | Add `%USERPROFILE%\.local\bin` to Path in Environment Variables ([section 1a](#1a-install-1)), then open a **new** terminal |
| Codex: "Missing environment variable COSMOSHUB_API_KEY" | The terminal was opened before the key was saved | Close it and open a new terminal |
| VS Code: the chat AI answers "What would you like to do with language models?" | The command was typed into the chat box | Close that box and use `Ctrl+Shift+P` |
| VS Code: models don't appear | The model list was not read yet | Restart VS Code |
| The Claude Code extension still uses the subscription | The wrapper decided CosmosHub was unusable, or the setting was not read | Read the reason in `~/.cosmohub/wrapper.log`, run `check.ps1`, then restart VS Code |
| Codex extension: "connection refused" / cannot connect | The router is not running (the Codex extension cannot start it itself) | Run `check.ps1`. If "Router process" fails, run `install.ps1` again or type `cosmohub-status` in a terminal |

---

### 6. Cost and security

- **There is a hidden cost:** CosmosHub adds about **2,000 tokens** of hidden instructions to every request. Even a short question counts as about 2,000 input tokens. Watch your balance in the dashboard.
- **Never share your API key** in a chat, a screenshot or a Git repository. Claude Code's `settings.json` contains the key, so don't commit it.
- If a key has leaked, **create a new key** in the CosmosHub dashboard and delete the old one.
- Official support: contact the CosmosHub admin on Telegram (the link is in the dashboard).
- New account sign-up (referral link): **https://cosmosin.io/r/34D5W2DC**. Top up: **https://cosmosin.io**.

---

### 7. Optional: automatic fallback router (Windows)

For anyone who wants:
- CosmosHub to **switch models automatically** while the requested model is under maintenance, for example `gpt-6.1-sol`, then `gpt-6-sol`, then `kimi-k3.1-pro`, and so on.
- To **automatically go back to Claude models** as soon as CosmosHub offers them again.
- When the balance runs out, the session **continues on your Claude or ChatGPT subscription**. This only helps if you have a subscription.

The router is a small Node.js program with no dependencies. It only listens on `127.0.0.1:4141` (not reachable from other computers) and is protected by a local token.

> When using the router, **do not** put CosmosHub into `settings.json` (section 1b) or `config.toml` (section 2c). The router's launcher sets everything up.

#### Set up

1. Install Node.js 22+, Claude Code and/or Codex.
2. Clone this repo, then run its installer:
   ```powershell
   git clone https://github.com/bakhtiarrifai/cosmohub-router.git C:\Projects\cosmohub-router
   powershell -ExecutionPolicy Bypass -File C:\Projects\cosmohub-router\install.ps1
   ```
   The installer will:
   - ask for the API key if it is not saved yet;
   - allow local scripts for your user;
   - install the launcher in your PowerShell profile;
   - install the Codex profile;
   - build the VS Code wrapper;
   - start the router automatically when you log in to Windows.
3. Open a **new terminal**, then run `C:\Projects\cosmohub-router\check.ps1`. When everything is `[OK]`, it shows **All good.** Run it again after your next Windows restart. The "Router process" line should show the time you logged in, which proves the router started automatically.

> If you see *"running scripts is disabled on this system"*, you called `install.ps1` directly. Use the full command above (with `-ExecutionPolicy Bypass`).

#### Use

| Command | What it does |
|---|---|
| `claude` / `codex` | CosmosHub first (automatic model switching). If CosmosHub can't be used, the subscription is used automatically |
| `claude-sub` / `codex-sub` | Always use the subscription |
| `cosmohub-status` | Router health, the next target model, the last model used, and the routing log |
| `cosmohub-model` | Show auto/manual mode and the model per slot |
| `cosmohub-model -List` | List the model IDs available on CosmosHub |
| `cosmohub-model -Watch` | Watch routing changes in a separate terminal (Ctrl+C to stop) |
| `cosmohub-model opus kimi-k3.1-pro` | Lock the opus slot to that model, with no silent fallback |
| `cosmohub-model opus auto` | Put the opus slot back on automatic fallback |
| `C:\Projects\cosmohub-router\check.ps1` | Full check of every part (useful after a Windows restart) |

On start you'll see `[cosmohub] Using CosmosHub API (... models)`. If the balance runs out mid-session, the tool shows an error. Type `/exit`, and the launcher continues the same conversation on the subscription (`claude --continue` / `codex resume --last`).

#### See and pick models manually

Each launcher shows a table of **Next request** (the predicted next target), **Last used** (the target of the last generation request the upstream accepted), and when. The slot/model name in Claude Code's header can stay an alias; use `cosmohub-model` for the real routing target. The router does not claim to know which internal model sits behind a CosmosHub alias.

```powershell
# Load the new functions in an already open terminal after updating the repo:
. C:\Projects\cosmohub-router\cosmohub.ps1

cosmohub-model                         # status of every slot
cosmohub-model -List                   # list of model IDs
cosmohub-model opus kimi-k3.1-pro       # manual choice for the opus slot
cosmohub-model sonnet deepseek-v4-pro   # the sonnet slot can differ
cosmohub-model codex gpt-6-sol          # choice for Codex
cosmohub-model opus auto               # back to automatic fallback
```

Choices are saved in `~/.cosmohub/model-selection.json` and survive a router or computer restart. They apply **globally per slot** to the next requests, including terminal sessions and extensions that are already open; requests already running are not changed. Manual mode does not switch models when a model fails: the error is returned so the choice never changes silently. Out-of-balance handling still applies.

To pick an exact model **only within a Claude Code session**, type `/model hub-model/kimi-k3.1-pro`. The `hub-model/` prefix locks the ID with no fallback and ignores the global per-slot choice. Go back to `/model opus` to follow the slot setting again.

While you work, open a second terminal and run `cosmohub-model -Watch` to see the latest routing target. Watch reads the status every second, not every event: requests that come very close together can be missed. **Last used** is global, not specific to one conversation, and is only recorded once the upstream accepts a generation request (not a guarantee that the stream finished). Background tasks can change it too. After a router restart, the last status is empty until a new request comes in. Generation responses include the headers `x-cosmohub-model` and `x-cosmohub-mode`; the local endpoints `GET /router/models` and `POST /router/models` (`{"slot":"opus","model":"kimi-k3.1-pro"}`, or `model: null` for auto) need the router token.

If the router is still running an old version, stop **only the Node process running `cosmohub-router\router.js`** while no generation is in progress, then run `cosmohub-status` to start the new version. There is no need to rerun the installer or rebuild the wrapper for this feature.

#### Change the model order

Edit `config.json`. Each slot holds a list of models tried in order. A pattern like `claude-opus*` means "the newest Claude Opus model, if available".

```json
"opus":   ["claude-opus*",   "gpt-6.1-sol", "gpt-6-sol", "kimi-k3.1-pro", "deepseek-v4-pro", "qwen-3.8-max"],
"sonnet": ["claude-sonnet*", "gpt-6-sol", "kimi-k2.7-code", "glm-5.3", "deepseek-v4-pro"],
"haiku":  ["claude-haiku*",  "deepseek-v4-flash", "glm-5.3-flash", "gemini-3.8-flash"],
"codex":  ["gpt-6.1-sol", "gpt-6-sol", "gpt-5.6-sol", "kimi-k3.1-pro", "deepseek-v4-pro"]
```

After changing `config.json`, stop the router process (the `node.exe` running `router.js`). The next `claude` or `codex` starts it again automatically.

#### How it works

```
claude / codex  ──>  router 127.0.0.1:4141  ──>  CosmosHub
                      model down (404/5xx/429)?  try the next model
                      out of balance (401/402/403)? record it, then the tool stops
launcher (cosmohub.ps1) ── after the tool closes: out of balance? continue on the subscription
```

Subscription logins **never** pass through the router. Subscriptions are only used through their official apps, as Anthropic's and OpenAI's terms require.

---

### 8. Optional: Claude Code & Codex extensions in VS Code

Needs the router from [section 7](#7-optional-automatic-fallback-router-windows) (run `install.ps1` first).

#### Claude Code extension

`install.ps1` builds `bin\claude-hub.exe`, a wrapper the extension uses to start Claude. The wrapper uses CosmosHub when the router is usable, and falls back to the subscription when it isn't. If the router is not running yet, the wrapper starts it. Add to VS Code's `settings.json`:

```json
"claudeCode.claudeProcessWrapper": "C:\\Projects\\cosmohub-router\\bin\\claude-hub.exe"
```

Restart VS Code. Every wrapper decision (CosmosHub or subscription) is logged in `~/.cosmohub/wrapper.log`. To use only the subscription for a while, remove the line above from `settings.json`.

#### Codex extension

The Codex extension always reads the main `~/.codex/config.toml`. Add this at the **very top** of that file:

```toml
model_provider = "cosmohub"

[model_providers.cosmohub]
name = "CosmosHub (local router)"
base_url = "http://127.0.0.1:4141/v1"
env_key = "COSMOHUB_ROUTER_TOKEN"
wire_api = "responses"
```

Restart VS Code. With this setting the `codex` command in the terminal also goes through CosmosHub, while `codex-sub` keeps using the ChatGPT subscription (`-c model_provider=openai`). The Codex extension does **not** switch to the subscription automatically when the balance runs out. If that happens, remove the block above from `config.toml`.

The Codex extension ships its own Codex engine, whose version can differ from Codex CLI. Both read the same `config.toml`. For small tasks such as generating titles, the extension uses a light model (for example `gpt-6-luna`). That model is also on CosmosHub, so it goes through the router too.

#### How to check that the extensions use CosmosHub

Send one message in the extension's panel, then check:

| Extension | What to check | Sign of success |
|---|---|---|
| Claude Code | `check.ps1`, the "Last VS Code Claude launch" line (or `~/.cosmohub/wrapper.log`) | Starts with `cosmoshub ::` |
| Claude Code | `~/.cosmohub/router.log` | Has a line `/v1/messages claude-opus-5-5 -> ... 200` |
| Codex | `~/.cosmohub/router.log` | Has a line `/v1/responses ... 200` |
| Codex | The first line of the newest session file in `~/.codex/sessions/` | Contains `"originator":"codex_vscode"` and `"model_provider":"cosmohub"` |

---

### 9. GitHub Copilot desktop app & Chatbox

Both can be installed with winget and connected **directly** to CosmosHub, without the router:

```powershell
winget install --id GitHub.CopilotApp -e
winget install --id Bin-Huang.Chatbox -e
```

#### GitHub Copilot desktop app

1. Open the GitHub Copilot app and sign in with your GitHub account.
2. Open **Settings → Model Providers**, then add an **OpenAI-compatible** provider.
3. Enter the endpoint **`https://api.cosmosin.io/v1`** and your CosmosHub API key. The **`/v1` is required**; without it the app cannot reach the CosmosHub models.
4. When starting a session, pick a CosmosHub model in the model picker, for example `gpt-6.1-sol`.

Copilot Business/Enterprise accounts: an admin must enable the *Enable custom models (BYOK)* policy.

#### Chatbox

1. Open Chatbox. If the welcome screen asks for a license, choose the option to use **your own API key**; the license is only for the paid "Chatbox AI" service. Then go to **Settings → Model Provider** and add a new provider of type **OpenAI API Compatible**.
2. Fill in:
   - Name: `CosmosHub`
   - API Host: `https://api.cosmosin.io` (without `/v1`)
   - API Path: `/v1/chat/completions`
   - API Key: your CosmosHub key
3. Click **Fetch** to load the model list, or add them by hand: `gpt-6.1-sol`, `kimi-k3.1-pro`, `deepseek-v4-flash`, and so on.
4. Pick a CosmosHub model in a new conversation.

Menu names can differ slightly between app versions.

---

### License

MIT. See [LICENSE](LICENSE).
