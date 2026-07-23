[CmdletBinding()]
param(
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ProjectRoot)) {
        throw 'Unable to locate the App repository. Pass -ProjectRoot.'
    }
}

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$required = @(
    'AGENTS.md',
    'pubspec.yaml',
    'docs\development-guide.md',
    'docs\testing-release-playbook.md',
    'docs\release-configuration.md',
    'docs\design\app-ui-v1.md',
    'docs\modules\membership.md'
)

$missing = @($required | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf)
})
if ($missing.Count -gt 0) {
    throw ('Missing required project files: ' + ($missing -join ', '))
}

Write-Output '=== APP GIT ==='
& git -C $root status --short --branch
if ($LASTEXITCODE -ne 0) { throw 'git status failed.' }
& git -C $root log -5 --oneline
if ($LASTEXITCODE -ne 0) { throw 'git log failed.' }
& git -C $root diff --stat
if ($LASTEXITCODE -ne 0) { throw 'git diff --stat failed.' }
& git -C $root diff --cached --stat
if ($LASTEXITCODE -ne 0) { throw 'git diff --cached --stat failed.' }
& git -C $root remote -v
if ($LASTEXITCODE -ne 0) { throw 'git remote -v failed.' }

$protected = @(& git -C $root ls-files --others --exclude-standard -- 'docs/handoff-account-features.md')
if ($protected.Count -gt 0) {
    Write-Output 'PROTECTED_USER_FILE: docs/handoff-account-features.md'
}

Write-Output 'KEY_DOCS: PASS'

$workspace = Split-Path -Parent $root
$infoRoot = Join-Path $workspace 'pushup-ai-info'
if (-not (Test-Path -LiteralPath $infoRoot -PathType Container)) {
    Write-Output 'INFO_REPO: NOT_FOUND (required before release/platform tasks)'
    Write-Output 'PREFLIGHT_RESULT: PASS_WITH_INFO_WARNING'
    exit 0
}

$infoRequired = @('README.md', 'AGENTS.md', 'SECURITY.md')
$infoMissing = @($infoRequired | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $infoRoot $_) -PathType Leaf)
})
if ($infoMissing.Count -gt 0) {
    throw ('Missing required info repository files: ' + ($infoMissing -join ', '))
}

# Allowed private remotes for the info repo (multi-machine handoff sync).
# Only public/ + handoffs/ + CHANGELOG.md are synced; private/ is gitignored
# and purged from history. Leave empty to keep the legacy "no remote" behavior.
$allowedInfoRemotes = @(
    'https://github.com/mhgd3250905/pushup-ai-info.git',
    'git@github.com:mhgd3250905/pushup-ai-info.git'
)

$infoRemotes = @(& git -C $infoRoot remote)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect info repository remotes.' }
foreach ($remoteName in $infoRemotes) {
    $remoteUrl = & git -C $infoRoot remote get-url $remoteName
    if ($LASTEXITCODE -ne 0) { throw "Unable to read info remote URL for $remoteName." }
    if ($allowedInfoRemotes -notcontains $remoteUrl) {
        throw ("The info repository remote '$remoteUrl' is not in the allowlist. Stop release/platform work.")
    }
}

Write-Output '=== INFO GIT ==='
& git -C $infoRoot status --short --branch
if ($LASTEXITCODE -ne 0) { throw 'Info repository git status failed.' }
if ($infoRemotes.Count -eq 0) {
    Write-Output 'INFO_REMOTE: NONE'
} else {
    Write-Output ("INFO_REMOTE: ALLOWED (" + ($infoRemotes -join ', ') + ")")
}

# private/ must never be tracked or staged: it holds real endpoints / resource
# IDs / config records and is local-only (gitignored, history-purged).
$privateTracked = @(& git -C $infoRoot ls-files -- 'private/')
if ($privateTracked.Count -gt 0) {
    throw ("private/ is tracked in the info repo (local-only, must not be synced): " + ($privateTracked -join ', '))
}

$secretRoot = Join-Path $workspace 'secrets'
$ledger = @(
    Get-ChildItem -LiteralPath $secretRoot -Filter 'PushupAI-*.md' -File -ErrorAction SilentlyContinue
)
if ($ledger.Count -gt 0) {
    Write-Output 'AUTHORITATIVE_LEDGER: PRESENT'
} else {
    Write-Output 'AUTHORITATIVE_LEDGER: NOT_FOUND (required before platform writes)'
}

Write-Output 'PREFLIGHT_RESULT: PASS'
