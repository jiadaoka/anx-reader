<#
.SYNOPSIS
    鸿蒙 HAP 构建入口。

.DESCRIPTION
    把这条链路里所有"本机才知道"的东西收在一处：SDK 路径、环境变量、缺失的工程配置、
    第三方包补丁。构建结束（无论成败）都会还原第三方包，避免影响日常 Android / 桌面构建。

    第三方包补丁见 scripts/ohos_patch_target_platform.py：鸿蒙版 Flutter 给 TargetPlatform
    加了 ohos 取值，几个第三方包的 switch 因此不再穷尽，编译会直接失败。

.PARAMETER Mode
    debug 或 release。

.PARAMETER Arch
    x64（模拟器镜像）或 arm64（真机）。

.PARAMETER Signed
    产物要装到设备时使用：去掉 --no-codesign。要求已在 DevEco 里配好签名。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\build_ohos.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\build_ohos.ps1 -Mode release -Arch arm64
#>
[CmdletBinding()]
param(
    [ValidateSet('debug', 'release')][string]$Mode = 'debug',
    [ValidateSet('x64', 'arm64')][string]$Arch = 'x64',
    [switch]$Signed
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$flutterSdk = if ([string]::IsNullOrWhiteSpace($env:JIAANX_OHOS_FLUTTER_ROOT)) {
    'I:\sdk\flutter'
} else {
    $env:JIAANX_OHOS_FLUTTER_ROOT.Trim()
}
$devecoRoot = if ([string]::IsNullOrWhiteSpace($env:JIAANX_DEVECO_ROOT)) {
    'D:\Program Files\Huawei\DevEco Studio'
} else {
    $env:JIAANX_DEVECO_ROOT.Trim()
}
$pubCache = if ([string]::IsNullOrWhiteSpace($env:JIAANX_PUB_CACHE)) {
    'I:\pub_cache'
} else {
    $env:JIAANX_PUB_CACHE.Trim()
}
$python = if ([string]::IsNullOrWhiteSpace($env:JIAANX_PYTHON)) {
    'python'
} else {
    $env:JIAANX_PYTHON.Trim()
}
$buildExit = 1

function Write-Step {
    param([string]$Message)
    Write-Host "[ohos] $Message" -ForegroundColor Cyan
}

if (-not (Test-Path -LiteralPath (Join-Path $flutterSdk 'bin\flutter.bat'))) {
    throw "找不到鸿蒙版 Flutter：$flutterSdk"
}
if (-not (Test-Path -LiteralPath (Join-Path $devecoRoot 'tools\hvigor\bin\hvigorw.bat'))) {
    throw "找不到 DevEco / hvigor：$devecoRoot"
}

$env:FLUTTER_ROOT = $flutterSdk
$env:PUB_CACHE = $pubCache
$env:FLUTTER_STORAGE_BASE_URL = 'https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com'
$env:HOS_SDK_HOME = Join-Path $devecoRoot 'sdk'
$env:DEVECO_SDK_HOME = $env:HOS_SDK_HOME
$env:JAVA_HOME = Join-Path $devecoRoot 'jbr'
# flutter_audio_session 的 fork 里 example 用了 Git LFS，远端缺对象时 checkout 会失败；
# 构建不需要 example，直接跳过 LFS 下载。
$env:GIT_LFS_SKIP_SMUDGE = '1'
$env:PATH = @(
    (Join-Path $devecoRoot 'tools\hvigor\bin'),
    (Join-Path $devecoRoot 'tools\ohpm\bin'),
    (Join-Path $devecoRoot 'tools\node'),
    (Join-Path $flutterSdk 'bin'),
    $env:PATH
) -join ';'

Push-Location $root
try {
    Write-Step "补齐 ohos 工程配置"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\setup_ohos.ps1')
    if ($LASTEXITCODE -ne 0) { throw "setup_ohos.ps1 失败（exit $LASTEXITCODE）" }

    Write-Step "给第三方包补 TargetPlatform.ohos"
    & $python (Join-Path $root 'scripts\ohos_patch_target_platform.py') apply
    if ($LASTEXITCODE -ne 0) { throw "ohos_patch_target_platform.py apply 失败（exit $LASTEXITCODE）" }

    $flutterArgs = @('build', 'hap', "--$Mode", '--target-platform', "ohos-$Arch")
    if (-not $Signed) { $flutterArgs += '--no-codesign' }

    Write-Step ("flutter " + ($flutterArgs -join ' '))
    # PowerShell 5.1 会把原生命令的 stderr 当成错误记录，脚本级的 Stop 会直接中断；
    # flutter 往 stderr 写正常进度，这里临时放开，退出码以 $LASTEXITCODE 为准。
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & (Join-Path $flutterSdk 'bin\flutter.bat') @flutterArgs
        $buildExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
}
finally {
    Write-Step "还原第三方包"
    & $python (Join-Path $root 'scripts\ohos_patch_target_platform.py') restore | Out-Host
    Pop-Location
}

$hap = Join-Path $root 'build\ohos\hap\entry-default-unsigned.hap'
if (Test-Path -LiteralPath $hap) {
    $size = [math]::Round((Get-Item -LiteralPath $hap).Length / 1MB, 1)
    Write-Step "产物：$hap（$size MB）"
}

exit $buildExit
