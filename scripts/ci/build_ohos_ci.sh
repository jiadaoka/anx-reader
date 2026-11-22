#!/usr/bin/env bash
#
# 鸿蒙 HAP 的 CI 构建入口（只跑在 Linux runner 上）。
#
# 和 scripts/build_ohos.ps1 的分工：
# - build_ohos.ps1 是本地开发用的试验构建：吃本机 DevEco Studio 布局
#   （tools\hvigor、jbr、sdk），路径由 JIAANX_* 环境变量覆盖；
# - 本脚本只在 CI 用：工具链来自 ErBWs/setup-ohos 铺好的 DevEco command-line-tools
#   布局（bin/、tool/node、sdk/）和现克隆的 CPF-Flutter/flutter_flutter，不认任何
#   本机路径，也不改 build_ohos.ps1 的行为。
#
# 前置（由 .github/workflows/build-hap.yaml 准备，这里只检查）：
#   flutter        在 PATH 上，且是鸿蒙版（支持 flutter build hap）
#   HOS_SDK_HOME   指向 command-line-tools/sdk
#   python3       补 TargetPlatform.ohos
#   unzip、jq      校验产物里的版本号
#
# 用法：
#   bash scripts/ci/build_ohos_ci.sh --tag v0.1.0 [--mode release] [--arch arm64]
#
# 产物：build/ci/JiaAnx-<versionName>-harmonyos-<arch>-unsigned.hap
# 有 GITHUB_OUTPUT / GITHUB_STEP_SUMMARY 时顺带写 hap_path / version /
# version_code / sha256。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

MODE='release'
ARCH='arm64'
TAG=''

PYTHON="${JIAANX_PYTHON:-python3}"

VERSION_NAME=''
VERSION_CODE=''
PATCHED=0

log() {
    printf '[ohos-ci] %s\n' "$*"
}

die() {
    printf '[ohos-ci] 失败：%s\n' "$*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "PATH 上没有 $1"
}

usage() {
    cat <<'EOF'
鸿蒙 HAP 的 CI 构建入口（只跑在 Linux runner 上）。

用法：
  bash scripts/ci/build_ohos_ci.sh --tag v0.1.0 [--mode release] [--arch arm64]

参数：
  --tag <tag>    要构建的 tag，决定 versionName / versionCode（形如 v0.1.0、v0.1.0-rc.1）
  --mode <mode>  debug 或 release，默认 release
  --arch <arch>  x64 或 arm64，默认 arm64

前置：flutter（鸿蒙版）在 PATH 上，HOS_SDK_HOME 指向 command-line-tools/sdk，
      并装有 python3、unzip、jq。详细说明见脚本头部注释。
EOF
}

# 还原第三方包：不管构建成败都跑，和 build_ohos.ps1 的 finally 对齐。
cleanup() {
    local exit_code=$?
    if [[ "$PATCHED" == 1 ]]; then
        log '还原第三方包'
        "$PYTHON" scripts/ohos_patch_target_platform.py restore || true
    fi
    exit "$exit_code"
}

# tag -> versionName / versionCode。规则与本地 workflow 的原 PowerShell 一致：
# 只取 X.Y.Z（可带 -rc.1），忽略 tag 里的 +N；versionCode 按 X.Y.Z 稳定换算。
resolve_version() {
    local tag="$1"
    local raw="${tag#refs/tags/}"
    raw="${raw#v}"
    local version_name="${raw%%+*}"
    version_name="$(printf '%s' "$version_name" | tr -d '[:space:]')"

    if [[ ! "$version_name" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-[0-9A-Za-z.-]+)?$ ]]; then
        die "tag 版本必须形如 vX.Y.Z 或 vX.Y.Z-rc.1：${tag}"
    fi

    local major=$((10#${BASH_REMATCH[1]}))
    local minor=$((10#${BASH_REMATCH[2]}))
    local patch=$((10#${BASH_REMATCH[3]}))
    local prerelease="${BASH_REMATCH[4]}"

    if ((major > 999 || minor > 99 || patch > 99)); then
        die "版本段超出可换算范围：${version_name}"
    fi

    # 线上不写构建号；versionCode 只做安装升级用的稳定换算。
    # X.Y.Z -> major*1000000 + minor*10000 + patch*100 + (预发布序号 1..98 / 正式 99)
    local suffix=99
    if [[ -n "$prerelease" ]]; then
        suffix=1
        if [[ "$prerelease" =~ ([0-9]+)$ ]]; then
            suffix=$((10#${BASH_REMATCH[1]}))
        fi
        if ((suffix < 1)); then
            suffix=1
        fi
        if ((suffix > 98)); then
            suffix=98
        fi
    fi

    VERSION_NAME="$version_name"
    VERSION_CODE=$((major * 1000000 + minor * 10000 + patch * 100 + suffix))
}

# ohos/build-profile.json5 是每台机器自己的签名/产品配置，不入库；CI 从模板生成。
# 语义与 scripts/setup_ohos.ps1 一致：已存在就跳过。
ensure_build_profiles() {
    local pairs=(
        'ohos/build-profile.example.json5:ohos/build-profile.json5'
        'ohos/entry/build-profile.example.json5:ohos/entry/build-profile.json5'
    )
    local pair template target
    for pair in "${pairs[@]}"; do
        template="${pair%%:*}"
        target="${pair##*:}"
        [[ -f "$template" ]] || die "缺少模板：${template}"
        if [[ -f "$target" ]]; then
            log "已存在，跳过：${target}"
            continue
        fi
        cp "$template" "$target"
        log "已生成：${target}"
    done
}

# hvigor 找 SDK 的一个入口就是 ohos/local.properties 里的 hwsdk.dir——本机那份由
# DevEco 写成这个键，且这个文件不入库。CI 上没有 DevEco，缺文件时补一条，
# 与 DEVECO_SDK_HOME 双保险；flutter 构建时自己写进去的 flutter.sdk 等键不受影响。
ensure_local_properties() {
    local props='ohos/local.properties'
    if [[ -f "$props" ]]; then
        log "已存在，跳过：${props}"
        return
    fi
    printf 'hwsdk.dir=%s\n' "$HOS_SDK_HOME" >"$props"
    log "已生成：${props}（hwsdk.dir=${HOS_SDK_HOME}）"
}

# 定位 HAP：flutter 不同版本落点不同，先看已知路径，再按文件名兜底。
locate_hap() {
    local candidate
    for candidate in \
        'build/ohos/hap/entry-default-unsigned.hap' \
        'ohos/entry/build/default/outputs/default/entry-default-unsigned.hap'; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    candidate="$(find build/ohos/hap ohos/entry/build -type f -name '*-unsigned.hap' 2>/dev/null | sort | head -n 1 || true)"
    if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    log '没找到 HAP，现有 *.hap：' >&2
    find build ohos -type f -name '*.hap' 2>/dev/null >&2 || log '（一个都没有）' >&2
    return 1
}

# 产物自检：HAP 里的 versionName / versionCode 必须与 tag 换算的一致。
verify_hap() {
    local hap="$1"
    local module_json got_name got_code

    module_json="$(unzip -p "$hap" module.json 2>/dev/null || true)"
    if [[ -z "$module_json" ]]; then
        die "HAP 里读不到 module.json：${hap}"
    fi

    got_name="$(printf '%s' "$module_json" | jq -r '.app.versionName // empty')"
    got_code="$(printf '%s' "$module_json" | jq -r '.app.versionCode // empty')"

    [[ "$got_name" == "$VERSION_NAME" ]] || die "HAP 版本名不符：${got_name} != ${VERSION_NAME}"
    [[ "$got_code" == "$VERSION_CODE" ]] || die "HAP 版本号不符：${got_code} != ${VERSION_CODE}"
}

emit_output() {
    local name="$1" value="$2"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf '%s=%s\n' "$name" "$value" >>"$GITHUB_OUTPUT"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --tag)
        TAG="${2:-}"
        shift 2
        ;;
    --mode)
        MODE="${2:-}"
        shift 2
        ;;
    --arch)
        ARCH="${2:-}"
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        die "未知参数：$1（用 --help 看用法）"
        ;;
    esac
done

[[ -n "$TAG" ]] || TAG="${GITHUB_REF_NAME:-}"
[[ -n "$TAG" ]] || die '没有 tag：传 --tag vX.Y.Z，或让 workflow 提供 GITHUB_REF_NAME'
case "$MODE" in
debug | release) ;;
*) die "--mode 只能是 debug 或 release：${MODE}" ;;
esac
case "$ARCH" in
x64 | arm64) ;;
*) die "--arch 只能是 x64 或 arm64：${ARCH}" ;;
esac

need_cmd flutter
need_cmd "$PYTHON"
need_cmd unzip
need_cmd jq
[[ -n "${HOS_SDK_HOME:-}" ]] || die 'HOS_SDK_HOME 为空：CI 里要先跑 ErBWs/setup-ohos'

resolve_version "$TAG"
log "tag=${TAG} version=${VERSION_NAME} versionCode=${VERSION_CODE} mode=${MODE} arch=${ARCH}"

ensure_build_profiles
ensure_local_properties

# 不要把 FLUTTER_STORAGE_BASE_URL 指到华为 OBS：那个镜像只放鸿蒙自己的产物，
# 标准引擎产物（engine_stamp.json、linux-x64/artifacts.zip 等）在它上面是 404。
# 鸿蒙产物由 SDK 走 FLUTTER_OHOS_STORAGE_BASE_URL 单独取，默认就是华为 OBS。
export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$HOS_SDK_HOME}"
# flutter_audio_session 的 fork 里 example 用了 Git LFS，远端缺对象时 checkout 会失败。
export GIT_LFS_SKIP_SMUDGE=1

trap cleanup EXIT

log 'flutter pub get'
flutter pub get

# 生成物不入库（.gitignore 里 lib/gen/、*.g.dart、*.freezed.dart），干净的克隆里
# 一个都没有；本地能编只是因为开发机上早就生成过。顺序与 build_windows.ps1 /
# build_linux_appimage.sh 一致：先 gen-l10n，再 build_runner。
log 'flutter gen-l10n'
flutter gen-l10n

log '代码生成（freezed / json_serializable / flutter_gen）'
dart run build_runner build --delete-conflicting-outputs

log '给第三方包补 TargetPlatform.ohos'
PATCHED=1
"$PYTHON" scripts/ohos_patch_target_platform.py apply

# 版本用命令行传，不靠改文件：flutter build hap 会用 build name / build number
# 重写 ohos/AppScope/app.json5 与 ohos/local.properties 里的版本
# （flutter_tools/lib/src/ohos/hvigor_utils.dart 的 updateProjectVersion /
# updateLocalProperties），sed 改过的 app.json5 会被覆盖回去。
flutter_args=(
    build hap "--${MODE}"
    --target-platform "ohos-${ARCH}"
    --no-codesign
    --build-name "$VERSION_NAME"
    --build-number "$VERSION_CODE"
)
log "flutter ${flutter_args[*]}"
flutter "${flutter_args[@]}"

hap="$(locate_hap)" || die '构建结束但没有 HAP 产物'
verify_hap "$hap"

mkdir -p build/ci
artifact="build/ci/JiaAnx-${VERSION_NAME}-harmonyos-${ARCH}-unsigned.hap"
cp -f "$hap" "$artifact"

size="$(du -h "$artifact" | cut -f1)"
sha256="$(sha256sum "$artifact" | cut -d' ' -f1)"

log "artifact=${artifact}"
log "size=${size} sha256=${sha256}"

emit_output hap_path "$artifact"
emit_output version "$VERSION_NAME"
emit_output version_code "$VERSION_CODE"
emit_output sha256 "$sha256"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        printf '### JiaAnx %s · HarmonyOS %s · unsigned\n' "$VERSION_NAME" "$ARCH"
        printf -- '- file: `%s`\n' "$artifact"
        printf -- '- versionCode: %s\n' "$VERSION_CODE"
        printf -- '- size: %s\n' "$size"
        printf -- '- sha256: `%s`\n' "$sha256"
    } >>"$GITHUB_STEP_SUMMARY"
fi
