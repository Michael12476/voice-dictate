# Dictate from your iPhone

Your phone sends audio to your Windows PC. The PC runs your local Whisper model and rewrites the transcript with your own Codex login, then returns text to the phone. The PC must be awake and Voice Dictate must be running.

## Connect your own devices

1. Install [Tailscale](https://tailscale.com/download) on your PC and phone. Sign into your own account on both devices and confirm they appear in the same private network.
2. Run `setup.cmd` and choose phone setup. It checks Tailscale and FFmpeg, creates a private `phone-token.txt`, and enables `phone_endpoint` in your local settings.
3. Restart Voice Dictate using its desktop shortcut. On the PC, run `tailscale ip -4` to find its private address.

Keep port **47614** private. Restrict Tailscale access to devices you own; do not use Funnel, a public tunnel, or router port forwarding. HTTP here travels inside Tailscale's encrypted connection. No public server is needed.

## Create an Apple Shortcut

In Apple's Shortcuts app, create a shortcut with these actions:

1. **Record Audio**. Choose when recording should stop.
2. **Get Contents of URL**: `http://YOUR-PC-TAILSCALE-IP:47614/dictate`.
3. Expand its options: method **POST**, request body **File**, and choose the recorded audio as the file.
4. Add the header **Authorization**. Its value is `Bearer ` followed by the token from your PC's `phone-token.txt`.
5. **Copy to Clipboard** using the text returned by the URL action. Optionally add **Show Result**.

Open the token file privately to transfer its contents. Never put its value in a Git commit, shared shortcut, chat message, screenshot, or public QR code. The shortcut contains a credential; keep it private.

Apple describes request methods, headers, and file bodies in its [Get Contents of URL guide](https://support.apple.com/guide/shortcuts/request-your-first-api-apd58d46713f/ios). Tailscale also provides an optional [Connect action for Shortcuts](https://tailscale.com/docs/features/mac-ios-shortcuts).

Uploads are limited to **20 MiB** and **5 minutes** of audio, with a **45-second** decode time limit. Longer recordings are rejected instead of returning a partial transcript. The endpoint handles one request at a time. WAV, MP3, AAC/M4A, FLAC, and OGG are supported through FFmpeg; use an ordinary audio recording.

## Troubleshooting

- **401**: the Authorization header is absent or does not match the PC's token.
- **400**: send the recording as a File body. The endpoint requires one Content-Length and does not accept chunked transfer.
- **413**: shorten the recording or use a smaller audio file.
- **Cannot connect**: confirm the PC is awake, both devices are connected to Tailscale, the private address is correct, and Windows Firewall allows the app on that private connection. Check `dictate.log` for startup errors without sharing its transcript contents.
- **Processing failed**: check FFmpeg installation and recording format on the PC.

To disable the endpoint, set `phone_endpoint` to `false` in `settings.json` and restart the app. To replace the token, disable it first, remove `phone-token.txt`, rerun setup, update your private shortcut, and restart. Removing a device from Tailscale and rotating the token revokes that device's access.

Phone setup requires your own devices and sign-ins. This repository's automated checks use dummy uploads and do not verify your phone, tailnet, Windows Firewall, or account.
