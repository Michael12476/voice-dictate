# Windows setup

Use your own Windows PC, microphone, local voice model, and Codex/ChatGPT account with access to Codex. Voice recognition runs locally. Rewriting sends text to your Codex account and uses its limits. No API key is required.

## Guided setup

1. Extract or clone the complete repository into a folder you will keep. Do not run from inside a ZIP. Prefer a private, writable folder rather than a shared or cloud-synced folder.
2. Double-click `setup.cmd` in File Explorer. It uses Windows PowerShell 5.1 and changes execution policy for that process only. Run as your normal Windows user.
3. Agree to dependency/model downloads. If 64-bit Python 3.13 or Node LTS is missing, setup offers to install it through winget. You can decline, install it yourself, then rerun setup. Node LTS must be at least 22.12 for the optional settings app.
4. Start with the default CPU model, `base.en` with `int8`. It transcribes English. Allow about 1 GB of available RAM and at least 2 GB of free disk for dependencies and the model. Downloads go into this repository's `models` folder.
5. Install the Codex CLI when asked, then finish the browser login yourself using your own account. Setup checks `codex.cmd login status` without opening credential or global configuration files. The default rewrite model is `gpt-6-luna`; enter another Codex model ID if your account needs it. Login status confirms a login, not model access.
6. Phone setup, the Electron settings app, and starting at Windows sign-in are separate optional prompts. All default to no. If you choose the settings app, setup runs `npm.cmd ci` against its existing lockfile.
7. After setup succeeds, double-click **Voice Dictate** on your Desktop yourself. Tap Right Alt to start and stop recording. Esc cancels. Setup does not start the app.

Setup creates `.venv`, installs `requirements.txt`, loads the selected model, and saves `settings.json` after the required steps succeed. It preserves unrelated settings. A failed install can leave downloaded packages or model files for the next attempt. It never copies someone else's model, account, or dictation history.

The Desktop shortcut targets `.venv\Scripts\pythonw.exe` with this repository's `dictate.py` as its argument and the repository as its working directory. This hides the console. Launching from Explorer keeps the app outside an AI assistant's job. Keep the folder in place; rerun setup to recreate shortcuts after moving it. A previously created Startup shortcut stays until you delete it from `shell:startup`.

For assistant help, use the prompt in [AI-SETUP.md](AI-SETUP.md).

## Optional NVIDIA GPU

Choose GPU only if this PC has an NVIDIA GPU with a working driver. Setup checks `nvidia-smi`, installs `requirements-gpu.txt`, checks that CTranslate2 sees a CUDA device, and loads `large-v3-turbo` with `cuda` and `int8_float16`. The GPU requirements add cuBLAS for CUDA 12 and cuDNN 9 for CUDA 12. DLL folders inside `.venv` are added for model loading.

Allow at least 6 GB of free disk for the larger model, CUDA libraries, and installation cache. Start with roughly 4 GB or more of free VRAM. Actual memory and speed depend on the card and other running apps. If the driver, DLLs, or available memory do not work, rerun `setup.cmd` and choose CPU. Setup does not install GPU drivers or silently downgrade packages.

## Optional phone

Phone mode is off by default. Install [Tailscale for Windows](https://tailscale.com/download/windows) on your PC and Tailscale on your phone. Sign both into **your own same tailnet**. Install a Windows build of [FFmpeg](https://ffmpeg.org/download.html), which this app uses to decode phone recordings. Finish these steps yourself before accepting the phone prompt.

Setup verifies FFmpeg and the PC's Tailscale IPv4 address. It adds their executable folders to your persistent Windows user PATH so the app can find them after an Explorer shortcut launch. The usual Tailscale location is `C:\Program Files\Tailscale\tailscale.exe`. For FFmpeg, give the full path to `ffmpeg.exe` when asked, such as `C:\tools\ffmpeg\bin\ffmpeg.exe`. A PATH change made only in a terminal will not survive a later shortcut launch. If Windows still uses an old PATH, sign out and back in before launching.

Setup generates a cryptographically random token in the local, Git-ignored `phone-token.txt`, restricts that file to your Windows user, and never prints the token. An existing valid token is kept. Open the file privately and enter `Bearer <your token>` as the iPhone Shortcut's `Authorization` header. Keep the token out of chats, screenshots, commits, and synced folders. Follow [PHONE.md](PHONE.md) for the Shortcut and PC address.

Do not enable Tailscale Funnel, port forwarding, or a public tunnel. The endpoint accepts an authenticated recording up to 20 MiB and five minutes. FFmpeg decoding has a 45-second timeout; phone requests are processed one at a time. These are server limits, not a completed phone connectivity test.

## Manual setup

Use this route if you want to perform each step yourself. Open Windows PowerShell in the repository folder. Check every command's exit status before continuing. Python 3.13 must be 64-bit. A newer or older default Python does not replace the required version.

Install prerequisites from [Python's Windows downloads](https://www.python.org/downloads/windows/) and [Node LTS](https://nodejs.org/en/download), or choose these exact winget packages:

```powershell
winget.exe install --id Python.Python.3.13 --exact --source winget
if ($LASTEXITCODE -ne 0) { throw 'Python install failed' }
winget.exe install --id OpenJS.NodeJS.LTS --exact --source winget
if ($LASTEXITCODE -ne 0) { throw 'Node install failed' }
```

Close and reopen PowerShell after installation. Create the environment and install the CPU dependencies and model:

```powershell
py.exe -3.13 -m venv .venv
if ($LASTEXITCODE -ne 0) { throw 'Python 3.13 environment creation failed' }
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { throw 'Dependency install failed' }
.\.venv\Scripts\python.exe install_model.py --model base.en --device cpu
if ($LASTEXITCODE -ne 0) { throw 'Voice model setup failed' }
npm.cmd install -g @openai/codex
if ($LASTEXITCODE -ne 0) { throw 'Codex install failed' }
codex.cmd login
if ($LASTEXITCODE -ne 0) { throw 'Finish your own browser login and retry' }
codex.cmd login status
if ($LASTEXITCODE -ne 0) { throw 'Codex is not logged in' }
```

If `py.exe` is unavailable, replace it with the quoted absolute path to your Python 3.13 interpreter and the PowerShell call operator, such as `& 'C:\path\python.exe' -m venv .venv`. Do not reuse a `.venv` created with a different Python.

For GPU, install `requirements-gpu.txt` and run the model installer with `--model large-v3-turbo --device cuda`, checking both exit codes. Do not choose CUDA solely because a GPU is installed; NVIDIA drivers and matching libraries must work.

After the model and your login succeed, create `settings.json` with the values below. If the file already exists, edit only these keys and preserve your other settings. Pick a rewrite model your account can use.

```json
{
  "whisper_model": "base.en",
  "whisper_device": "cpu",
  "whisper_compute": "int8",
  "codex_model": "gpt-6-luna",
  "phone_endpoint": false
}
```

Use `large-v3-turbo`, `cuda`, and `int8_float16` together for the GPU choice. Leave phone off until its prerequisites and private token are ready. Rerun `setup.cmd` to create shortcuts or configure the optional phone. Alternatively, start the app yourself from PowerShell in the repository:

```powershell
.\.venv\Scripts\pythonw.exe .\dictate.py
```

Read `dictate.log` if startup fails. An assistant must leave the final launch to you in Explorer or your own terminal.

To install the optional settings app manually, run `npm.cmd ci` in `settings-app`, check the exit code, then run `npm.cmd start` yourself when you want to open it. The project uses npm because it already has an npm lockfile and Electron scripts.

## Troubleshooting

- **Python found, but wrong version:** setup looks specifically for 64-bit Python 3.13 through `py.exe`, standard install paths, the Python registry entry, and PATH. For a custom location, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -PythonPath 'C:\path\python.exe'`. Existing environments with the wrong version are rejected. Rename `.venv` yourself and rerun setup.
- **winget missing or install blocked:** install the prerequisite manually from its official download page. On managed PCs, ask your administrator. Close setup and rerun it after installing.
- **PowerShell script blocked:** use `setup.cmd`. It only sets the child process's execution policy. Organizational policy can still block scripts; do not change machine policy to work around it.
- **npm or Codex missing:** reopen a terminal after Node installation. Use `npm.cmd` and `codex.cmd` on Windows to avoid blocked `.ps1` wrappers. Setup adds the selected Node directory and npm global directory to your user PATH. Run as the same Windows user that will use dictation.
- **Browser login incomplete:** run `codex.cmd login` yourself, then `codex.cmd login status`. Use your own account. Never send an assistant credentials or the contents of `auth.json` or global Codex configuration.
- **Rewrite model unavailable:** change only `codex_model` in `settings.json` to a model available to your account, then restart the app. Setup does not call the model to verify access.
- **Model download or CUDA load failed:** check internet access to Hugging Face and free disk space. Rerun setup with CPU if CUDA reports DLL, driver, or memory errors. `models` is the shared installer/runtime cache for this repository.
- **Phone mode unavailable:** confirm Tailscale is connected on both devices, the same tailnet is in use, and FFmpeg/Tailscale folders are in your persistent user or system PATH. Keep the PC awake. Follow [PHONE.md](PHONE.md), and verify the Shortcut's private header yourself.
- **Shortcut starts then disappears:** check `dictate.log` beside the app for a fatal startup error. Close any already running copy. Confirm Windows permits desktop apps to use your microphone.

## Offline setup check

Contributors can run this check without installing dependencies, downloading a model, authenticating, opening a GUI, or starting dictation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -SelfCheck
if ($LASTEXITCODE -ne 0) { throw 'Setup self-check failed' }
```

It checks settings preservation, rejects a non-object settings file, validates token boundaries, and verifies that a failed native command stops setup. It does not test a live installation, account access, GPU inference, shortcuts, or phone connectivity.

Command references: [Microsoft's Python manifest](https://github.com/microsoft/winget-pkgs/tree/master/manifests/p/Python/Python/3/13), [Node LTS manifest](https://github.com/microsoft/winget-pkgs/tree/master/manifests/o/OpenJS/NodeJS/LTS), [official Codex CLI documentation](https://learn.chatgpt.com/docs/codex/cli), [Codex login reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli), and [faster-whisper GPU requirements](https://github.com/SYSTRAN/faster-whisper#gpu).
