param(
    [Parameter(Mandatory)]
    [ValidatePattern('\A[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*\z')]
    [string]$Milestone
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE."
    }
}

Push-Location (Join-Path $PSScriptRoot '..')
try {
    $branch = Invoke-Checked git @('branch', '--show-current')
    if ($branch -ne 'recovery/beta5') {
        throw 'Check out recovery/beta5 before publishing a milestone.'
    }
    $changes = Invoke-Checked git @('status', '--porcelain')
    if ($changes) {
        throw 'Commit the milestone and clean the working tree before publishing.'
    }
    $commit = Invoke-Checked git @('rev-parse', 'HEAD')
    $tag = "milestone/$Milestone"

    Invoke-Checked flutter @('analyze')
    Invoke-Checked flutter @('test')

    $currentCommit = Invoke-Checked git @('rev-parse', 'HEAD')
    $changes = Invoke-Checked git @('status', '--porcelain')
    if ($currentCommit -ne $commit -or $changes) {
        throw 'The checkout changed during verification. Review it and retry.'
    }

    Invoke-Checked git @(
        'push', '--atomic', 'origin',
        "${commit}:refs/heads/recovery/beta5",
        "${commit}:refs/tags/$tag"
    )
} finally {
    Pop-Location
}
