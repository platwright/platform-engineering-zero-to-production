#Requires -Version 5.1
<#
.SYNOPSIS
  Reports which course tools are installed and their versions (Windows).
.DESCRIPTION
  Informational: run it any time to see what you still need to set up.
  Exits 0 if all CORE tools are present, 1 otherwise.
  See 00-orientation/environment-setup.md for installation instructions.
.EXAMPLE
  ./scripts/check-prerequisites.ps1
#>

$ErrorActionPreference = 'SilentlyContinue'
$script:MissingCore = 0

function Test-Tool {
  param(
    [string]$Command,
    [ValidateSet('core', 'optional')][string]$Level,
    [string]$Purpose,
    [string[]]$VersionArgs = @('--version')
  )
  $exe = Get-Command $Command -ErrorAction SilentlyContinue
  if ($exe) {
    $raw = (& $Command @VersionArgs 2>&1 | Select-Object -First 1) -as [string]
    $ver = $raw.Trim()
    Write-Host ("  [ok]      {0,-11} {1}" -f $Command, $ver) -ForegroundColor Green
  }
  elseif ($Level -eq 'core') {
    Write-Host ("  [MISSING] {0,-11} (core) {1}" -f $Command, $Purpose) -ForegroundColor Red
    $script:MissingCore++
  }
  else {
    Write-Host ("  [--]      {0,-11} (optional) {1}" -f $Command, $Purpose) -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "Platform Engineering - prerequisite check" -ForegroundColor White
Write-Host "-----------------------------------------"
Write-Host ""

Write-Host "Core tools (needed from the early modules)" -ForegroundColor White
Test-Tool git       core 'version control'             @('--version')
Test-Tool docker    core 'build and run containers'    @('--version')
Test-Tool kubectl   core 'operate Kubernetes clusters' @('version', '--client')
Test-Tool kind      core 'local Kubernetes clusters'   @('version')
Test-Tool terraform core 'infrastructure as code'      @('version')
Test-Tool go        core 'operators and platform CLIs' @('version')
Test-Tool python    core 'automation and scripting'    @('--version')

Write-Host ""
Write-Host "Recommended tools (introduced later; install as you go)" -ForegroundColor White
Test-Tool helm      optional 'Kubernetes package manager'   @('version', '--short')
Test-Tool kustomize optional 'Kubernetes config overlays'   @('version')
Test-Tool gcloud    optional 'Google Cloud CLI'             @('--version')
Test-Tool jq        optional 'JSON processing'              @('--version')
Test-Tool node      optional 'Backstage / tooling'          @('--version')
Test-Tool trivy     optional 'image vulnerability scanning' @('--version')
Test-Tool cosign    optional 'image signing (Sigstore)'     @('version')
Test-Tool argocd    optional 'GitOps CLI (ArgoCD)'          @('version', '--client')

Write-Host ""
Write-Host "-----------------------------------------"
if ($script:MissingCore -eq 0) {
  Write-Host "All core tools are installed. You're ready to start." -ForegroundColor Green
  Write-Host ""
  exit 0
}
else {
  Write-Host ("{0} core tool(s) missing. See 00-orientation/environment-setup.md to install them." -f $script:MissingCore) -ForegroundColor Red
  Write-Host ""
  exit 1
}
