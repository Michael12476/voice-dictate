# Ask an AI assistant to help with setup

Use a coding assistant with access to your local Windows repository and terminal. Replace the folder in this prompt with your checkout's path. Review the assistant's proposed install steps and finish browser sign-in and phone setup yourself.

```text
Help me set up Voice Dictate on my own Windows PC.
Repository: C:\path\to\voice-dictate

Read AGENTS.md if present, docs/SETUP.md, docs/PHONE.md, requirements.txt,
requirements-gpu.txt, setup.cmd, setup.ps1, install_model.py,
and relevant runtime source before running anything. Inspect my Windows
host and repository.

Use the existing Windows PowerShell 5.1 setup. Start with base.en on CPU
and int8 unless I choose NVIDIA GPU after you explain its prerequisites,
disk use, and VRAM needs. Use this repository's .venv and models folder.
Choose 64-bit Python 3.13 explicitly, even if another Python is on PATH.
Use Node LTS, npm.cmd, and codex.cmd on Windows. Check native exit codes.
Preserve the existing npm lockfile and unrelated settings.json keys.

Explain which packages/downloads the setup needs, then help run setup.cmd
in a human-accessible interactive terminal. Let me answer its prompts.
If your tools cannot support interactive input, tell me to double-click
setup.cmd myself and use redacted error messages to troubleshoot.
Do not automate prompt answers, silently enable optional features, or
pretend a blocked/noninteractive wizard succeeded.

Use MY Codex/ChatGPT subscription and login. Default the rewrite model
to gpt-6-luna, but let me choose an available model if my account differs.
Never request an API key. Never read, copy, or print auth.json, global
Codex configuration, browser cookies, or another person's credentials.
I will finish browser authentication myself. Do not call the rewrite
provider merely to test setup without my permission.

Phone mode is optional and off by default. If I choose it, I will install
Tailscale on my PC and phone and sign them into MY same tailnet. FFmpeg
must be installed and discoverable after an Explorer shortcut launch.
Use a persistent user/system PATH rather than a terminal-only PATH.
Let setup generate the local ignored phone-token.txt privately. Never
read, print, or upload that token into chat. I will open it myself and
add the bearer header to my iPhone Shortcut using docs/PHONE.md.
Do not create a public tunnel, port forwarding, or Tailscale Funnel.

Create/verify the Desktop shortcut and ask separately about Windows
Startup. Do not start dictate.py, pythonw.exe, or the settings
GUI in an assistant tool/background job. End by telling me to double-click
Voice Dictate on my Desktop myself in File Explorer so it outlasts your job.

Report what you changed, what you checked, and what remains for me.
Do not claim live model, login, rewrite, GPU, microphone, or phone behavior
was tested unless it actually was tested with my authorization.
```

Share the failing step and a redacted error message when asking for help. Do not paste secrets, token files, dictation history, or unreviewed logs into chat. Your assistant can inspect the setup scripts without needing any of those files.
