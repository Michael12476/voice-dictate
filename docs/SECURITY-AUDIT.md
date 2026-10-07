# Security audit and release checks

## Source audit

The audit reviewed the original recovery worktree before public-release hardening. Its baseline was commit `6cf65d33f2f0e90a325819a635834053566f7e66` plus maintained recovery changes. Baseline line numbers below differ from this release.

The standard audit completed reconnaissance, two hunting waves, coverage critics, independent candidate validation, schema checks, and fresh final record verification. Coverage was partial: 30 units, including eight covered units, eleven candidate units with final decisions, three deferred units, and eight excluded backup units. Fourteen unique candidates produced **zero confirmed vulnerabilities, thirteen needs-validation leads, and one rejection**. Needs-validation leads have no severity.

No approved execution sandbox was available. The audit ran source checks only. It did not execute the original application, tests, models, microphone, clipboard, phone service, or Codex provider. No exploit or resource-exhaustion effect was reproduced. Both unmodified report and ledger validators passed through their exported in-memory validation APIs.

The final coverage critic identified an additional gap, which was deferred. The deferred areas were pill text-layout cost, Codex reply retention, and rewrite deadline/lock lifetime. Dependency implementation, downloaded models, private runtime values, ignored inactive backups, and live deployment configuration were excluded. No prior compatible audit ledger existed.

## Unresolved baseline leads

Each lead requires the evidence shown below. A source omission alone does not establish an attack. Access from another principal must be distinguished from the owner's intended use.

| Lead | Baseline entry | Missing decisive evidence |
|---|---|---|
| Possible cross-principal recording control through the loopback test hook | `dictate.py:492` | A separate local principal's authority and reachability. |
| A silent connection may stall the loopback control test hook | `dictate.py:490` | A bounded runtime effect on the local test listener. |
| Possible operator-context disclosure to a separate phone caller | `dictate.py:511` | A separate caller's context permissions and actual model disclosure. |
| Older pending dictations lose tracking of later interruptions | `dictate.py:377` | A lower-trust boundary and an observed unintended delivery. |
| Potential operator UI delay from unbudgeted control-event processing | `dictate.py:490` | A separate caller and meaningful UI interference. |
| Obsolete live inference may contend with accepted dictation work | `dictate.py:492` | A lower-trust trigger and meaningful inference interference. |
| Recording retention has no source-defined ceiling; security impact remains unverified | `dictate.py:492` | A lower-trust recording trigger and meaningful resource impact. |
| Phone decoder secondary-input confinement remains unverified | `dictate.py:509` | Actual decoder behavior, caller authority, and a protected secondary input. |
| Phone inference relies on unverified network admission for peer authorization | `dictate.py:509` | Effective tailnet admission and caller permissions. |
| Shared phone upload pathname may misbind concurrent responses | `dictate.py:511` | A bounded concurrent response-misbinding observation. |
| Phone work lacks source-defined budgets for shared dictation resources | `dictate.py:508` | A lower-trust admitted caller and meaningful shared resource interference. |
| Finished-recording queue lacks aggregate bounds; security impact remains unverified | `dictate.py:492` | A lower-trust queue trigger and meaningful resource impact. |
| Potential settings slowdown from retained phone dictation records | `dictate.py:508` | A lower-trust producer and meaningful settings-window interference. |

The cancellation claim was rejected as a security finding. Source showed a lifecycle concern but did not establish an unauthorized action or a promised pending-job revocation boundary.

The phone changes below reduce several baseline exposures. They do not turn these unresolved baseline leads into reproduced vulnerabilities or verified exploit fixes.

## Public-release changes

- Phone mode defaults off and requires a private bearer token. Authentication precedes body reading.
- Uploads require one valid Content-Length. Transfer-Encoding, duplicate headers, oversized bodies, and incomplete uploads are rejected.
- Uploads use separate temporary directories and are removed after decoding.
- Phone requests are serialized. Bodies are limited to 20 MiB and decoded audio to five minutes.
- FFmpeg uses a 45-second timeout and format/protocol allowlists. These flags do not prove isolation from every local file reference or decoder defect.
- The unused desktop test command listener was removed.
- The settings bridge checks its window, main frame, and packaged page. It validates write payloads and blocks navigation and new windows.
- Routine rewrite timing logs omit transcript text.
- Codex reply reading no longer retains a growing list of return values. Ready messages cannot bypass an expired reply deadline.
- Setup uses each person's own local model, Codex login, and optional private phone token.

Recordings, queued desktop work, and retained history still have no aggregate retention budget. Model inference and lock waiting are not covered by one end-to-end deadline. This remains a personal desktop app for one trusted operator and their own devices.

## Release checks

These checks ran after the source audit closed, against the separate hardened release. They use dummy state and do not demonstrate an exploit against the original source.

| Check | Result |
|---|---|
| `python test_recovery.py` | Passed: interruption recovery, normal delivery, paste failure, and session ownership |
| `python test_security.py` | Passed: phone admission, upload limits/cleanup, replies/deadlines, startup errors, and incomplete history |
| `node settings-app/test_security.cjs` | Passed: sender and payload validation, settings preservation, navigation isolation |
| `setup.ps1 -SelfCheck` | Passed under Windows PowerShell 5.1: settings preservation, token boundaries, native failures |
| Python, JavaScript, and PowerShell source syntax | Passed |
| `npm audit --package-lock-only --ignore-scripts` | Zero reported vulnerabilities in the settings lockfile |
| Eight pinned Python/GPU direct releases | PyPI reported no known vulnerabilities and none were yanked |

Local Python checks used Python 3.14. The [Windows CI workflow](../.github/workflows/checks.yml) repeats the dummy checks on Python 3.13, the installer target. The PyPI check covered direct pins; it did not resolve or audit all Python transitive dependencies. Advisory databases can change. See [PyPI's release-specific vulnerability metadata](https://docs.pypi.org/api/json/#known-vulnerabilities).

Clean installation, GPU inference, real Codex model entitlement, new-user shortcuts, microphone access, and phone connectivity remain unverified. The wizard checks model loading and the user's login during their own setup. Login does not establish access to a particular rewrite model.

Claude reviewed the integrated release and found no critical issues. Follow-up changes added startup diagnostics, protected invalid settings from overwrite, documented AltGr, removed the duplicate launcher, and corrected small setup/history handling issues. The loaded settings page now uses the same URL as the sender check. Chromium URL normalization and a live AltGr layout were not tested.

| Review item | Change |
|---|---|
| Hidden startup failures | Fatal errors reach the private log before third-party imports |
| AltGr takeover | README explains the hotkey conflict |
| Fast-mode overwrite | Invalid/unreadable settings are rejected; other keys survive |
| Duplicate launcher | Removed; shortcut and manual launch use the runtime directly |
| Incomplete history | Invalid final rows are skipped within the recent-line window |
| Setup encoding | Settings are read explicitly as UTF-8 |
| Model reset | Setup retains a valid existing rewrite model as the prompt default |
| Persistent PATH | Raw entries and registry type survive; existing machine/user entries are reused |
| Page URL mismatch | Loading and sender checks use the same file URL |
| Connection timeout | Uses the standard request-handler timeout |
| Phone diagnostics | Logs exception type without its message or audio |
| Duplicate startup cost | Instance guard runs before model loading |
| Explicit interpreter | An invalid supplied Python path fails instead of silently falling back |

## Publication controls

Publication uses a fresh Git history and an explicit file allowlist. Personal settings, vocabulary, style, recordings, history, logs, model caches, Codex credentials, and phone tokens are excluded. Before publication, scan the staged files and all reachable Git blobs for credentials and personal metadata. Pattern scanning cannot prove that arbitrary sensitive prose is absent; review the file manifest and examples as well.

Whisper processes audio locally. Codex receives the transcript and selected context for rewriting. Local history and error logs can remain sensitive even though Git ignores them. Follow [SECURITY.md](../SECURITY.md) and keep the app folder private.
