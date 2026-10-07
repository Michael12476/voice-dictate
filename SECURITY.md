# Security

Voice Dictate is a personal Windows desktop app. Each person uses their own Windows account, local model, Codex login, and optional phone connection. It is not a service for sharing one person's Codex account with other people.

- Run it as a standard Windows user.
- Keep Codex authentication in the Codex CLI's own credential storage. Do not copy it into this project.
- Keep settings, vocabulary, writing style, transcripts, usage, recordings, logs, voice profiles, and phone tokens out of Git. Check staged files before publishing changes.
- The phone endpoint is off by default. Enabling it requires a private bearer token and Tailscale. Only connect devices you own; restrict tailnet access to the PC and never expose this port through Funnel or public forwarding.
- Anyone who can read your local app folder can read its history and phone token. Keep that folder private and delete history when appropriate.
- Codex receives text and context for rewriting. Whisper processes audio locally; downloading a model contacts its model host.

The public release removes the local test command listener, authenticates and bounds phone uploads, pins dependencies, and limits the settings window's native bridge. Read [the audit report](docs/SECURITY-AUDIT.md) for the evidence and checks that could not be completed.

Report suspected vulnerabilities privately through this repository's GitHub **Security → Report a vulnerability** page. Avoid posting recordings, transcripts, credentials, or phone tokens in public issues.
