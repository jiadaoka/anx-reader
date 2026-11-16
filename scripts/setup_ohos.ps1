<#
.SYNOPSIS
    在 ohos 工程里生成 build-profile.json5。

.DESCRIPTION
    ohos/build-profile.json5 与 ohos/entry/build-profile.json5 会被 DevEco 写入本机
    签名配置（p12 / cer / p7b 的绝对路径），属于"每台机器不一样"的文件，所以只提交
    *.example.json5 模板，真实文件由本脚本按模板生成。

    已存在时不覆盖；改了模板想重新生成，再传 -Force。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\setup_ohos.ps1
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$pairs = @(
    @{ Template = 'ohos\build-profile.example.json5'; Target = 'ohos\build-profile.json5' },
    @{ Template = 'ohos\entry\build-profile.example.json5'; Target = 'ohos\entry\build-profile.json5' }
)

foreach ($pair in $pairs) {
    $template = Join-Path $root $pair.Template
    $target = Join-Path $root $pair.Target

    if (-not (Test-Path -LiteralPath $template)) {
        throw "缺少模板：$template"
    }
    if ((Test-Path -LiteralPath $target) -and -not $Force) {
        Write-Host "[ohos] 已存在，跳过：$($pair['Target'])"
        continue
    }

    Copy-Item -LiteralPath $template -Destination $target -Force
    Write-Host "[ohos] 已生成：$($pair['Target'])"
}
