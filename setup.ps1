#Requires -Version 5.1
param([string]$PythonPath, [switch]$SelfCheck)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = $PSScriptRoot

function Confirm-Step([string]$Question) {
    while ($true) {
        $answer = (Read-Host "$Question [y/N]").Trim()
        if ($answer -match '^(y|yes)$') { return $true }
        if ($answer -eq '' -or $answer -match '^(n|no)$') { return $false }
        Write-Host 'Please enter y or n.'
    }
}

function Invoke-Native([string]$FilePath, [string[]]$ArgumentList) {
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "Executable not found: $FilePath" }
    # Windows PowerShell turns native stderr into errors even when the command succeeds.
    $ErrorActionPreference = 'Continue'
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) { throw "$FilePath failed with exit code $LASTEXITCODE. Fix the error above and rerun setup.cmd." }
}

function Refresh-Path {
    # Retain the interpreter chosen for this run and add freshly installed persistent paths.
    $paths = @($env:Path, [Environment]::GetEnvironmentVariable('Path', 'Machine'),
              [Environment]::GetEnvironmentVariable('Path', 'User'))
    $env:Path = (($paths -join ';') -split ';' | Where-Object { $_.Trim() } |
        ForEach-Object { [Environment]::ExpandEnvironmentVariables($_.Trim()) } |
        Select-Object -Unique) -join ';'
}

function Add-UserPath([string]$Directory) {
    if ($Directory.Contains(';') -or -not [IO.Path]::IsPathRooted($Directory)) { throw 'Tool directory must be an absolute path without a semicolon.' }
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        $userPath = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $entries = @($userPath -split ';' | Where-Object { $_ })
        $combined = @($entries) + @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';')
        $expanded = @($combined | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_.Trim()) })
        if ($expanded -notcontains $Directory) {
            $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
            if ($key.GetValueNames() -contains 'Path') { $kind = $key.GetValueKind('Path') }
            $key.SetValue('Path', (($entries + $Directory) -join ';'), $kind)
        }
    } finally { $key.Dispose() }
    Refresh-Path
}

function Get-Python313 {
    $ErrorActionPreference = 'Continue'
    $probe = 'import sys,struct; sys.exit(1) if sys.version_info[:2] != (3,13) or struct.calcsize(''P'') != 8 else print(sys.executable)'
    if ($PythonPath) {
        if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) { throw 'The explicit -PythonPath executable does not exist.' }
        $found = & $PythonPath -c $probe 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $found) { throw 'The explicit -PythonPath must be 64-bit Python 3.13.' }
        return "$found"
    }
    $launcher = Get-Command py.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($launcher) {
        $found = & $launcher.Source -3.13 -c $probe 2>$null
        if ($LASTEXITCODE -eq 0 -and $found -and (Test-Path -LiteralPath "$found" -PathType Leaf)) { return "$found" }
    }
    $candidates = @("$env:LOCALAPPDATA\Programs\Python\Python313\python.exe", "$env:ProgramFiles\Python313\python.exe")
    foreach ($hive in @('HKCU:', 'HKLM:')) {
        $key = Get-ItemProperty "$hive\Software\Python\PythonCore\3.13\InstallPath" -ErrorAction SilentlyContinue
        if ($key -and $key.PSObject.Properties['ExecutablePath']) { $candidates += $key.ExecutablePath }
    }
    $onPath = Get-Command python.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($onPath) { $candidates += $onPath.Source }
    foreach ($candidate in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $found = & $candidate -c $probe 2>$null
            if ($LASTEXITCODE -eq 0 -and $found) { return "$found" }
        }
    }
}

function Get-NodeLts {
    $ErrorActionPreference = 'Continue'
    $command = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue
    $candidates = @("$env:ProgramFiles\nodejs\node.exe", "$env:LOCALAPPDATA\Programs\nodejs\node.exe")
    if ($command) { $candidates = @($command.Source) + $candidates }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            & $candidate -e 'let [a,b]=process.versions.node.split(''.'').map(Number); process.exit(process.release.lts && (a>22 || (a===22 && b>=12)) ? 0 : 1)' 2>$null
            if ($LASTEXITCODE -eq 0) { return $candidate }
        }
    }
}

function Install-Winget([string]$PackageId, [string]$ManualUrl) {
    $winget = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $winget) { throw "winget is missing. Install from $ManualUrl, close setup, then double-click setup.cmd again." }
    if (-not (Confirm-Step "Install $PackageId with winget? This downloads software and may ask for administrator approval.")) {
        throw "Install the prerequisite yourself from $ManualUrl, then rerun setup.cmd. See docs\AI-SETUP.md for assistant help."
    }
    Invoke-Native $winget.Source @('install', '--id', $PackageId, '--exact', '--source', 'winget')
    Refresh-Path
}

function Merge-Settings($Existing, [hashtable]$Choices) {
    if ($null -eq $Existing -or $Existing -isnot [pscustomobject]) { throw 'settings.json must contain a JSON object. Fix it or rename it, then rerun setup.' }
    $merged = [ordered]@{}
    foreach ($property in $Existing.PSObject.Properties) { $merged[$property.Name] = $property.Value }
    foreach ($key in $Choices.Keys) { $merged[$key] = $Choices[$key] }
    return $merged
}

function Test-PhoneToken([string]$Value) { return $Value -cmatch '\A[A-Za-z0-9_-]{32,128}\z' }

function Test-CodexLogin([string]$Codex) {
    $ErrorActionPreference = 'Continue'
    $status = & $Codex login status 2>&1
    return $LASTEXITCODE -eq 0 -and ($status -join ' ') -match 'ChatGPT'
}

function Ensure-PhoneToken {
    $path = Join-Path $root 'phone-token.txt'
    if (Test-Path -LiteralPath $path) {
        if (-not (Test-PhoneToken ([IO.File]::ReadAllText($path).Trim()))) {
            throw 'phone-token.txt is invalid. Back it up privately, remove it, and rerun setup to generate a new token.'
        }
    } else {
        $bytes = New-Object byte[] 32
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
        $token = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $encoded = [Text.Encoding]::ASCII.GetBytes($token)
            $stream.Write($encoded, 0, $encoded.Length)
        } finally { $stream.Dispose() }
    }
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $path -AclObject $acl
    Write-Host 'Phone token saved privately in phone-token.txt. Open it yourself for your Shortcut header. Do not paste it into chat.'
}

function New-DictateShortcut([string]$Folder) {
    if (-not $Folder -or -not (Test-Path -LiteralPath $Folder -PathType Container)) { throw "Shortcut folder unavailable: $Folder" }
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut((Join-Path $Folder 'Voice Dictate.lnk'))
    $shortcut.TargetPath = Join-Path $root '.venv\Scripts\pythonw.exe'
    $shortcut.Arguments = '"' + (Join-Path $root 'dictate.py') + '"'
    $shortcut.WorkingDirectory = $root
    $shortcut.Description = 'Voice Dictate: tap Right Alt to record'
    $shortcut.Save()
}

if ($SelfCheck) {
    # No installs, model downloads, authentication, or app launch.
    $merged = Merge-Settings ('{"fast":false,"custom":{"keep":7},"phone_endpoint":true}' | ConvertFrom-Json) @{
        whisper_model = 'base.en'; whisper_device = 'cpu'; whisper_compute = 'int8'; codex_model = 'gpt-6-luna'; phone_endpoint = $false
    }
    $roundTrip = $merged | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    if ($roundTrip.fast -ne $false -or $roundTrip.custom.keep -ne 7 -or $roundTrip.phone_endpoint -ne $false -or $roundTrip.whisper_device -ne 'cpu') { throw 'Settings preservation/default check failed.' }
    $rejected = $false
    try { $null = Merge-Settings @('not an object') @{} } catch { $rejected = $true }
    if (-not $rejected) { throw 'Invalid settings were accepted.' }
    if (-not (Test-PhoneToken ('a' * 43)) -or (Test-PhoneToken ('a' * 31)) -or (Test-PhoneToken ('a' * 129)) -or (Test-PhoneToken ('a' * 32 + '+')) -or (Test-PhoneToken ('a' * 32 + "`n"))) { throw 'Token validation failed.' }
    $rejected = $false
    try { Invoke-Native $env:ComSpec @('/d', '/c', 'exit 7') } catch { $rejected = $true }
    if (-not $rejected) { throw 'Native command failure was ignored.' }
    Write-Host 'PASS: settings preservation, invalid settings, token boundary, native exit failure.'
    exit 0
}

try {
    Set-Location -LiteralPath $root
    Write-Host 'Voice Dictate setup for your own Windows PC'
    Write-Host 'Use your own local voice model and your own Codex account/subscription. No API key is needed.'
    Write-Host 'Need help? Read docs\AI-SETUP.md. Setup downloads dependencies/model after you agree; it never starts dictation.'
    $settingsPath = Join-Path $root 'settings.json'
    $existing = [pscustomobject]@{}
    if (Test-Path -LiteralPath $settingsPath) { $existing = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    $null = Merge-Settings $existing @{}
    if (-not (Confirm-Step 'Continue with local setup and dependency/model downloads?')) { exit 0 }
    Refresh-Path
    $python = Get-Python313
    if (-not $python) {
        Install-Winget 'Python.Python.3.13' 'https://www.python.org/downloads/windows/'
        $python = Get-Python313
    }
    if (-not $python) { throw '64-bit Python 3.13 was not found. Close setup and relaunch setup.cmd, or use setup.ps1 -PythonPath C:\path\python.exe. An older default Python is not enough.' }
    $node = Get-NodeLts
    if (-not $node) {
        Install-Winget 'OpenJS.NodeJS.LTS' 'https://nodejs.org/en/download'
        $node = Get-NodeLts
    }
    if (-not $node) { throw 'Node LTS 22.12 or newer was not found. Close setup and relaunch setup.cmd after installing Node LTS.' }
    $nodeFolder = Split-Path -Parent $node
    $env:Path = $nodeFolder + ';' + $env:Path
    $npm = Join-Path $nodeFolder 'npm.cmd'
    if (-not (Test-Path -LiteralPath $npm -PathType Leaf)) { throw 'npm.cmd is missing beside node.exe. Reinstall Node LTS and rerun setup.' }
    Add-UserPath $nodeFolder
    $venvPython = Join-Path $root '.venv\Scripts\python.exe'
    if (Test-Path -LiteralPath (Join-Path $root '.venv')) {
        if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) { throw 'Existing .venv is incomplete. Rename it yourself and rerun setup.' }
        Invoke-Native $venvPython @('-c', 'import sys,struct; assert sys.version_info[:2]==(3,13) and struct.calcsize(''P'')==8, ''Existing .venv must use 64-bit Python 3.13. Rename .venv yourself and rerun setup.''')
    } else { Invoke-Native $python @('-m', 'venv', (Join-Path $root '.venv')) }
    if (-not (Test-Path -LiteralPath (Join-Path $root '.venv\Scripts\pythonw.exe') -PathType Leaf)) { throw 'pythonw.exe is missing from .venv. Rename the incomplete environment yourself and rerun setup.' }
    Invoke-Native $venvPython @('-m', 'pip', 'install', '-r', (Join-Path $root 'requirements.txt'))
    $model = 'base.en'; $device = 'cpu'; $compute = 'int8'
    Write-Host 'CPU default: base.en, English, int8. Allow about 1 GB RAM and 2 GB free disk for setup.'
    Write-Host 'Optional GPU: large-v3-turbo, CUDA, int8_float16. Needs NVIDIA CUDA 12/cuDNN 9 support, at least 6 GB free disk, and roughly 4 GB or more free VRAM.'
    if (Confirm-Step 'Use the optional NVIDIA GPU model instead?') {
        $nvidia = Get-Command nvidia-smi.exe -CommandType Application -ErrorAction SilentlyContinue
        if (-not $nvidia) { throw 'nvidia-smi.exe was not found. Install/update the NVIDIA driver, or rerun with CPU.' }
        Invoke-Native $nvidia.Source @('--query-gpu=name,memory.total,driver_version', '--format=csv')
        Invoke-Native $venvPython @('-m', 'pip', 'install', '-r', (Join-Path $root 'requirements-gpu.txt'))
        Invoke-Native $venvPython @('-c', 'import ctranslate2; assert ctranslate2.get_cuda_device_count()>0, ''No CUDA device found; update your NVIDIA driver or use CPU''')
        $model = 'large-v3-turbo'; $device = 'cuda'; $compute = 'int8_float16'
    }
    Invoke-Native $venvPython @((Join-Path $root 'install_model.py'), '--model', $model, '--device', $device)
    $prefix = (Invoke-Native $npm @('prefix', '-g') | Out-String).Trim()
    if (-not $prefix -or -not [IO.Path]::IsPathRooted($prefix)) { throw 'npm did not return an absolute global install directory.' }
    $codex = Join-Path $prefix 'codex.cmd'
    if (-not (Test-Path -LiteralPath $codex -PathType Leaf)) {
        if (-not (Confirm-Step 'Install the official Codex CLI for your account with npm install -g @openai/codex?')) { throw 'Codex is required for rewriting. Install it yourself, then rerun setup.' }
        Invoke-Native $npm @('install', '-g', '@openai/codex')
    }
    if (-not (Test-Path -LiteralPath $codex -PathType Leaf)) { throw 'Codex installation did not create codex.cmd. Check npm permissions and rerun setup.' }
    Add-UserPath $prefix
    Invoke-Native $codex @('--version')
    # Do not inspect Codex credential/config files. The CLI owns authentication.
    if (-not (Test-CodexLogin $codex)) {
        if (-not (Confirm-Step 'Sign in to YOUR Codex/ChatGPT account in your browser now? Finish the browser step yourself.')) { throw 'Run codex.cmd login yourself, then rerun setup. Never share credentials or paste an API key into chat.' }
        Invoke-Native $codex @('login')
        if (-not (Test-CodexLogin $codex)) { throw 'Codex did not report a ChatGPT login. Run codex.cmd login yourself using your own account, then rerun setup.' }
    }
    $defaultModel = 'gpt-6-luna'
    if ($existing.PSObject.Properties['codex_model'] -and $existing.codex_model -is [string] -and
        $existing.codex_model -cmatch '\A[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}\z') { $defaultModel = $existing.codex_model }
    $codexModel = (Read-Host "Rewrite model [$defaultModel], or enter a Codex model available to your own account").Trim()
    if (-not $codexModel) { $codexModel = $defaultModel }
    if ($codexModel -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}\z') { throw 'Enter a model ID without spaces or shell characters.' }
    Write-Host 'Login status does not verify access to that model. If rewrites fail, choose an available model in settings.json.'
    $phone = $false
    if (Confirm-Step 'Set up optional iPhone dictation on YOUR private Tailscale tailnet?') {
        Write-Host 'Install FFmpeg from https://ffmpeg.org/download.html and Tailscale from https://tailscale.com/download/windows.'
        Write-Host 'Sign this PC and your phone into YOUR same tailnet. Do not enable Funnel or any public tunnel. See docs\PHONE.md.'
        if (-not (Confirm-Step 'Have you finished those installs and signed both devices into YOUR same tailnet?')) { throw 'Finish the phone prerequisites, or rerun setup and leave phone off.' }
        $ffmpeg = Get-Command ffmpeg.exe -CommandType Application -ErrorAction SilentlyContinue
        if ($ffmpeg) { $ffmpegPath = $ffmpeg.Source } else { $ffmpegPath = (Read-Host 'Full path to ffmpeg.exe, for example C:\tools\ffmpeg\bin\ffmpeg.exe').Trim().Trim('"') }
        if (-not [IO.Path]::IsPathRooted($ffmpegPath) -or -not (Test-Path -LiteralPath $ffmpegPath -PathType Leaf) -or [IO.Path]::GetFileName($ffmpegPath) -ine 'ffmpeg.exe') { throw 'FFmpeg path is invalid. Install it, then rerun setup.' }
        Invoke-Native $ffmpegPath @('-version')
        Add-UserPath (Split-Path -Parent $ffmpegPath)
        $tailscale = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
        if (-not (Test-Path -LiteralPath $tailscale -PathType Leaf)) {
            $command = Get-Command tailscale.exe -CommandType Application -ErrorAction SilentlyContinue
            if (-not $command) { throw 'Tailscale is missing. Install/sign in, then rerun setup.' }
            $tailscale = $command.Source
        }
        $ip = (Invoke-Native $tailscale @('ip', '-4') | Out-String).Trim()
        $parsedIp = $null
        if (-not [Net.IPAddress]::TryParse($ip, [ref]$parsedIp) -or $parsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'Tailscale did not return an IPv4 address. Sign in and reconnect Tailscale.' }
        $ipBytes = $parsedIp.GetAddressBytes()
        if ($ipBytes[0] -ne 100 -or $ipBytes[1] -lt 64 -or $ipBytes[1] -gt 127) { throw 'Expected a private Tailscale IPv4 address in 100.64.0.0/10.' }
        Add-UserPath (Split-Path -Parent $tailscale)
        Ensure-PhoneToken
        $phone = $true
    }
    if (Confirm-Step 'Install the optional Electron settings app using its existing npm lockfile?') {
        Push-Location -LiteralPath (Join-Path $root 'settings-app')
        try { Invoke-Native $npm @('ci') } finally { Pop-Location }
    }
    $startup = Confirm-Step 'Start Voice Dictate automatically when YOU sign in to Windows?'
    $choices = @{ whisper_model = $model; whisper_device = $device; whisper_compute = $compute; codex_model = $codexModel; phone_endpoint = $phone }
    # Re-read at commit time so unrelated edits made while downloads ran survive.
    if (Test-Path -LiteralPath $settingsPath) { $existing = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    $merged = Merge-Settings $existing $choices
    $temp = $settingsPath + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temp, (($merged | ConvertTo-Json -Depth 100) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $settingsPath) { [IO.File]::Replace($temp, $settingsPath, $null) }
        else { [IO.File]::Move($temp, $settingsPath) }
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
    New-DictateShortcut ([Environment]::GetFolderPath('DesktopDirectory'))
    if ($startup) { New-DictateShortcut ([Environment]::GetFolderPath('Startup')) }
    Write-Host 'Setup complete. Double-click Voice Dictate on your Desktop yourself. Tap Right Alt to start/stop, Esc to cancel.'
    Write-Host 'The app has not been launched. Keep this repository in place; rerun setup after moving it.'
    if ($phone) { Write-Host 'Finish your iPhone Shortcut privately using docs\PHONE.md and phone-token.txt.' }
    exit 0
} catch {
    Write-Host "Setup stopped: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'See docs\SETUP.md and docs\AI-SETUP.md. Fix the reported step, then double-click setup.cmd again.'
    exit 1
}
