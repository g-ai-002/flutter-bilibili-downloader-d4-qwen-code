# -*- coding: utf-8 -*-
"""生成 flutter-bilibili-downloader-d4-qwen-code 开源软件版本清单。

用法：
    python .build/query_all_versions.py

数据来源：
    - Flutter 依赖：https://pub.dev/api/packages/<package>
    - Android Gradle Plugin / desugar_jdk_libs：Google Maven 的 maven-metadata.xml
    - Kotlin：Maven Central 的 maven-metadata.xml
    - Gradle：https://services.gradle.org/versions/all

「当前版本」：
    - Flutter 依赖：直接读取 pubspec.yaml；
    - Android 构建链：直接解析 android/ 下的 Gradle 配置；
    - CI 动作：直接解析 .github / .gitea 下的工作流文件。
"""
import json
import re
import ssl
import unicodedata
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'versions.md'

GOOGLE_MAVEN = 'https://dl.google.com/dl/android/maven2'
MAVEN_CENTRAL = 'https://repo1.maven.org/maven2'
GRADLE_VERSIONS = 'https://services.gradle.org/versions/all'
PUB_PACKAGE = 'https://pub.dev/api/packages/'

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

UA = {'User-Agent': 'Mozilla/5.0'}

PUBSPECS = ('pubspec.yaml',)

PRERELEASE_RE = re.compile(
    r'(?:^|[\-.+])(?:m\d+|rc[\-.]?\d*|cr\d+|alpha[\-.]?\d*|beta[\-.]?\d*|'
    r'snapshot|preview[\-.]?\d*|dev[\-.]?\d*|prerelease|milestone[\-.]?\d*|'
    r'ea[\-.]?\d*|incubating|pre[\-.]?\d*|next[\-.]?\d*|canary[\-.]?\d*|'
    r'experimental|nightly|test[\-.]?\d*)'
    # 纯数字的连字符后缀（如 npm 的 7.0.0-0）是预发布版，不能当作额外版本段排在正式版之上
    r'|-\d+$'
)


def is_stable(version):
    return not PRERELEASE_RE.search(version.lower())


def version_key(version):
    parts = re.split(r'[.\-+]', version)
    nums = []
    for p in parts:
        if p.isdigit():
            nums.append(int(p))
        else:
            break
    while len(nums) < 4:
        nums.append(-1)
    v = version.lower()
    # 变体优先级：-jre 最高，android 变体低于普通版本
    suffix_pref = 2 if 'jre' in v else (-1 if 'android' in v else 0)
    return tuple(nums[:4] + [suffix_pref])


def parse_major_minor(version):
    parts = re.split(r'[.\-+]', version)
    major = int(parts[0]) if parts and parts[0].isdigit() else None
    minor = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else None
    return major, minor


def compute_latest(current, all_versions):
    """返回 (MAJOR 最新, MINOR 最新, PATCH 最新)。"""
    stable = [v for v in all_versions if is_stable(v)]
    if not stable:
        stable = list(all_versions)
    if not stable:
        return 'N/A', 'N/A', 'N/A'

    major_latest = max(stable, key=version_key)
    cur_major, cur_minor = parse_major_minor(current)
    if cur_major is None:
        return major_latest, 'N/A', 'N/A'

    same_major = [v for v in stable if parse_major_minor(v)[0] == cur_major]
    minor_latest = max(same_major, key=version_key) if same_major else current

    if cur_minor is not None:
        same_minor = [v for v in stable
                      if parse_major_minor(v)[0] == cur_major
                      and parse_major_minor(v)[1] == cur_minor]
        patch_latest = max(same_minor, key=version_key) if same_minor else current
    else:
        patch_latest = minor_latest

    return major_latest, minor_latest, patch_latest


def fmt_ver(current, latest):
    if latest == 'N/A':
        return '`N/A`'
    if str(latest) == str(current):
        return f'`{latest}` (已是最新)'
    return f'`{latest}`'


# ---------------------------------------------------------------------------
# 依赖与构建链信息采集
# ---------------------------------------------------------------------------
# (显示名, pub 包名, 说明)
PUB_META = [
    ('Provider', 'provider', '状态管理'),
    ('Dio', 'dio', 'HTTP 客户端'),
    ('Shared Preferences', 'shared_preferences', '键值本地存储'),
    ('Path Provider', 'path_provider', '平台目录定位'),
    ('Intl', 'intl', '国际化与日期格式化'),
    ('Crypto', 'crypto', '哈希与加密算法'),
    ('Flutter Local Notifications', 'flutter_local_notifications', '本地通知'),
    ('URL Launcher', 'url_launcher', '外部链接与应用唤起'),
    ('FFmpeg Kit Extended Flutter', 'ffmpeg_kit_extended_flutter', '音视频处理（FFmpeg Kit 扩展）'),
    ('Window Manager', 'window_manager', '桌面窗口管理（Windows）'),
    ('Flutter Lints', 'flutter_lints', '官方 lint 规则集'),
]
PUB_TITLES = {pkg: name for name, pkg, _desc in PUB_META}
PUB_DESCS = {pkg: desc for _name, pkg, desc in PUB_META}

ACTION_DESCS = {
    'actions/checkout': '检出仓库代码',
    'actions/setup-java': '安装 JDK（Temurin）',
    'subosito/flutter-action': '安装指定版本 Flutter SDK',
    'actions/upload-artifact': '上传构建产物（GitHub）',
    'actions/download-artifact': '下载构建产物（GitHub）',
    'actions/gitea-upload-artifact': '上传构建产物（Gitea）',
    'actions/gitea-download-artifact': '下载构建产物（Gitea）',
    'softprops/action-gh-release': '创建 GitHub Release',
}


def parse_pubspec(rel):
    """解析 pubspec 的 dependencies / dev_dependencies，按声明顺序返回。"""
    text = (ROOT / rel).read_text(encoding='utf-8')
    section = None
    deps = []
    for line in text.splitlines():
        if re.match(r'^[A-Za-z_]', line) and line.rstrip().endswith(':'):
            section = line.strip()[:-1]
            continue
        match = re.match(r'^  ([A-Za-z0-9_]+):\s*(\S+)\s*$', line)
        if match and section in ('dependencies', 'dev_dependencies'):
            deps.append((match.group(1), match.group(2).strip("'\""), section))
    return deps


def collect_pub_deps():
    """汇总各 pubspec 的依赖：当前版本、引用文件、依赖类型。"""
    refs = {}
    types = {}
    order = []
    for rel in PUBSPECS:
        for pkg, version, dep_type in parse_pubspec(rel):
            if pkg not in refs:
                refs[pkg] = []
                types[pkg] = dep_type
                order.append((pkg, version))
            if rel not in refs[pkg]:
                refs[pkg].append(rel)
    return order, refs, types


def read_text(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def search(pattern, text, flags=0):
    match = re.search(pattern, text, flags)
    return match.group(1) if match else ''


def collect_project_info():
    pubspec = read_text('pubspec.yaml')
    wrapper = read_text('android/gradle/wrapper/gradle-wrapper.properties')
    settings = read_text('android/settings.gradle')
    app_gradle = read_text('android/app/build.gradle')
    gh_workflow = read_text('.github/workflows/build.yml')
    constants = read_text('lib/utils/constants.dart')

    return {
        'app_version': search(r'^version:\s*(\S+)', pubspec, re.M),
        'constants_version': search(r"version\s*=\s*'([^']+)'", constants),
        'flutter': search(r"FLUTTER_VERSION:\s*'([^']+)'", gh_workflow),
        'dart': search(r"^\s+sdk:\s*'([^']+)'", pubspec, re.M),
        'gradle': search(r'gradle-([\d.]+)-', wrapper),
        'agp': search(r'id "com\.android\.application" version "([^"]+)"', settings),
        'kotlin': search(r'id "org\.jetbrains\.kotlin\.android" version "([^"]+)"', settings),
        'compile_sdk': search(r'compileSdk\s+(\d+)', app_gradle),
        'target_sdk': search(r'targetSdk\s+(\d+)', app_gradle),
        'min_sdk': search(r'minSdk\s+(\d+)', app_gradle),
        'ndk': search(r'ndkVersion\s+"([^"]+)"', app_gradle),
        'java': search(r'sourceCompatibility JavaVersion\.VERSION_(\d+)', app_gradle),
        'abi': search(r"abiFilters\s+'([^']+)'", app_gradle),
        'kotlin_stdlib': search(r'kotlin-stdlib:([\d.]+)', app_gradle),
        'desugar': search(r'desugar_jdk_libs:([\d.]+)', app_gradle),
        'ffmpeg_builder': search(r"FFMPEG_KIT_BUILDER:\s*'([^']+)'", gh_workflow),
        'ffmpeg_bundle': search(r"FFMPEG_KIT_WIN_BUNDLE:\s*'([^']+)'", gh_workflow),
    }


def collect_actions():
    refs = {}
    for rel in ('.github/workflows/build.yml', '.gitea/workflows/build.yml'):
        text = read_text(rel)
        for match in re.finditer(r'^\s*uses:\s*([^\s#]+)@(\S+)', text, re.M):
            name, version = match.group(1), match.group(2)
            if '/' not in name:
                continue
            entry = refs.setdefault(name, {'version': version, 'refs': []})
            if rel not in entry['refs']:
                entry['refs'].append(rel)
    return refs


# ---------------------------------------------------------------------------
# 元数据查询
# ---------------------------------------------------------------------------
def fetch_text(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
        return resp.read().decode('utf-8', errors='replace')


def fetch_pub(pkg):
    try:
        data = json.loads(fetch_text(PUB_PACKAGE + pkg))
        return pkg, [v['version'] for v in data.get('versions', [])]
    except Exception:
        return pkg, None


def fetch_maven(base, group, artifact):
    url = f'{base}/{group.replace(".", "/")}/{artifact}/maven-metadata.xml'
    try:
        root = ET.fromstring(fetch_text(url))
        return [v.text for v in root.findall('.//version')]
    except Exception:
        return None


def fetch_gradle():
    try:
        data = json.loads(fetch_text(GRADLE_VERSIONS))
        versions = [
            entry['version'] for entry in data
            if re.fullmatch(r'\d+(?:\.\d+)+', entry.get('version', ''))
            and not entry.get('snapshot')
            and not entry.get('nightly')
            and not entry.get('broken')
        ]
        return versions
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Markdown 排版：表格按中文显示宽度对齐，引用块长句按 80 列折行
# ---------------------------------------------------------------------------
TOKEN_RE = re.compile(
    r'\[[^\]]*\]\([^)]*\)'    # Markdown 链接整体不拆行
    r'|`[^`]*`'               # 行内代码整体不拆行
    r'|（[^）]*）'             # 全角括号短语整体不拆行
    r'|[A-Za-z0-9\[\](){}<>/\\:;,.!?=_+*\'"#%&@$~^|-]+|[\u2e80-\u9fff\uff00-\uffef]| +'
)

CLOSING_PUNCT = set('）)]}】，。；：！？、》」』”’')


def display_width(s):
    return sum(2 if unicodedata.east_asian_width(ch) in ('W', 'F') else 1 for ch in s)


def _pad(s, width):
    return s + ' ' * max(0, width - display_width(s))


def _format_table(block):
    rows = []
    sep_idx = None
    for ln in block:
        s = ln.strip().strip('|')
        rows.append([c.strip() for c in s.split('|')])
    for i, r in enumerate(rows):
        if all(r) and all(set(c) <= set('-:') for c in r):
            sep_idx = i
            break
    ncol = max(len(r) for r in rows)
    for r in rows:
        r.extend([''] * (ncol - len(r)))
    widths = [0] * ncol
    for i, r in enumerate(rows):
        if i == sep_idx:
            continue
        for j, c in enumerate(r):
            widths[j] = max(widths[j], display_width(c))
    out = []
    for i, r in enumerate(rows):
        if i == sep_idx:
            out.append('|' + '|'.join('-' * (w + 2) for w in widths) + '|')
        else:
            out.append('|' + '|'.join(' ' + _pad(c, widths[j]) + ' ' for j, c in enumerate(r)) + '|')
    return out


BLOCKQUOTE_LIST_RE = re.compile(r'^> (?:[-*+] |\d+\. )')


def _wrap_blockquote(line, width=80):
    if not line.startswith('> ') or display_width(line) <= width:
        return [line]
    # 列表项续行按标记宽度缩进（`> - ` → `>   `），与列表内容对齐
    marker = BLOCKQUOTE_LIST_RE.match(line)
    prefix = '> ' + ' ' * (len(marker.group(0)) - 2) if marker else '> '
    cur = '> '
    out = []
    for tok in TOKEN_RE.findall(line[2:]):
        if not tok.strip():
            if display_width(cur) + display_width(tok) > width and cur.strip() != prefix.strip():
                out.append(cur.rstrip())
                cur = prefix
            else:
                cur += tok
        else:
            if (display_width(cur) + display_width(tok) > width
                    and cur.strip() != prefix.strip()
                    and tok not in CLOSING_PUNCT):
                out.append(cur.rstrip())
                cur = prefix
            cur += tok
    out.append(cur.rstrip())
    return out


def format_markdown(text):
    lines = text.split('\n')
    result = []
    i = 0
    while i < len(lines):
        ln = lines[i]
        if ln.startswith('|'):
            block = []
            while i < len(lines) and lines[i].startswith('|'):
                block.append(lines[i])
                i += 1
            result.extend(_format_table(block))
        elif ln.startswith('> '):
            result.extend(_wrap_blockquote(ln))
            i += 1
        else:
            result.append(ln)
            i += 1
    return '\n'.join(result)


# ---------------------------------------------------------------------------
# 文档组装
# ---------------------------------------------------------------------------
def build_markdown(info, pub_order, pub_refs, pub_types, pub_latest, build_latest, actions):
    lines = []
    lines.append('# 开源软件版本清单\n')
    lines.append('> 本文件由脚本 `.build/query_all_versions.py` 自动生成，数据来源：Flutter 依赖为 [pub.dev API](https://pub.dev/api/packages/)，Android 构建链为 [Google Maven](https://dl.google.com/dl/android/maven2/) / [Maven Central](https://repo1.maven.org/maven2/) / [Gradle 版本服务](https://services.gradle.org/versions/all)。')
    lines.append('>')
    lines.append('> **列说明**：')
    lines.append('> - **当前版本**：Flutter 依赖取自 `pubspec.yaml`；构建链取自 `android/` 下的 Gradle 配置')
    lines.append('> - **MAJOR 最新版本**：最新大版本线的最新稳定版（跨大版本升级，可能含破坏式变更）')
    lines.append('> - **MINOR 最新版本**：当前大版本线内的最新稳定版（同大版本升级，通常向后兼容）')
    lines.append('> - **PATCH 最新版本**：当前大版本.中版本线内的最新补丁版（仅 bug 修复）')
    lines.append('>')
    lines.append('> 标注 `(已是最新)` 表示当前版本已是该版本线最新。预发布版（alpha / beta / rc / dev / milestone）不计入最新版本。')
    lines.append('>')
    lines.append('> 刷新方式：运行 `python .build/query_all_versions.py` 重新生成\n')

    lines.append('## 项目基础信息\n')
    lines.append('| 项目 | 版本 |')
    lines.append('|------|------|')
    lines.append(f'| 应用版本 (`pubspec.yaml`) | {info["app_version"]} |')
    lines.append(f'| 应用内版本号 (`lib/utils/constants.dart`) | {info["constants_version"]} |')
    lines.append(f'| Flutter SDK（CI 固定版本） | {info["flutter"]} |')
    lines.append(f'| Dart SDK 约束 | {info["dart"]} |')
    lines.append(f'| compileSdk / targetSdk | {info["compile_sdk"]} / {info["target_sdk"]} |')
    lines.append(f'| minSdk | {info["min_sdk"]} |')
    lines.append(f'| NDK | {info["ndk"]} |')
    lines.append(f'| Java (source/target) | {info["java"]} |')
    lines.append(f'| 目标平台 | Android ({info["abi"]})、Windows (x64) |')
    lines.append('')

    lines.append('发布产物：Android APK（`android-arm64`）与 Windows ZIP（`windows-x86_64`），由 GitHub Actions 与 Gitea Actions 双流水线构建。\n')
    lines.append('---\n')

    # ---- Flutter 运行时依赖 / 开发依赖 ----
    sections = [
        ('1. Flutter 运行时依赖', 'dependencies'),
        ('2. Flutter 开发依赖', 'dev_dependencies'),
    ]
    for title, dep_type in sections:
        lines.append(f'## {title}\n')
        lines.append('| 组件 | 当前版本 | MAJOR 最新版本 | MINOR 最新版本 | PATCH 最新版本 | 引用文件 | 说明 | 类型 |')
        lines.append('|------|---------|----------------|----------------|----------------|----------|------|------|')
        for pkg, current in pub_order:
            if pub_types[pkg] != dep_type:
                continue
            name = PUB_TITLES.get(pkg, pkg)
            desc = PUB_DESCS.get(pkg, 'Flutter 依赖')
            ref = ' / '.join(f'`{r}`' for r in pub_refs[pkg])
            major_l, minor_l, patch_l = pub_latest.get(pkg, ('N/A', 'N/A', 'N/A'))
            lines.append(
                f'| {name} (`{pkg}`) | `{current}` | {fmt_ver(current, major_l)} | {fmt_ver(current, minor_l)} | '
                f'{fmt_ver(current, patch_l)} | {ref} | {desc} | {dep_type} |'
            )
        lines.append('')

    # ---- Android 构建链 ----
    build_deps = [
        ('Gradle', info['gradle'], '`android/gradle/wrapper/gradle-wrapper.properties`', 'Gradle Wrapper 分发包'),
        ('Android Gradle Plugin', info['agp'], '`android/settings.gradle`', 'Android 构建插件'),
        ('Kotlin Gradle Plugin', info['kotlin'], '`android/settings.gradle`', 'Kotlin 编译插件'),
        ('Kotlin Stdlib', info['kotlin_stdlib'], '`android/app/build.gradle`', 'Kotlin 标准库'),
        ('Desugar JDK Libs', info['desugar'], '`android/app/build.gradle`', 'Java 8+ API 脱糖支持'),
    ]
    lines.append('## 3. Android 构建链\n')
    lines.append('| 组件 | 当前版本 | MAJOR 最新版本 | MINOR 最新版本 | PATCH 最新版本 | 引用文件 | 说明 |')
    lines.append('|------|---------|----------------|----------------|----------------|----------|------|')
    for name, current, ref, desc in build_deps:
        major_l, minor_l, patch_l = build_latest.get(name, ('N/A', 'N/A', 'N/A'))
        lines.append(
            f'| {name} | `{current}` | {fmt_ver(current, major_l)} | {fmt_ver(current, minor_l)} | '
            f'{fmt_ver(current, patch_l)} | {ref} | {desc} |'
        )
    lines.append('')

    # ---- CI 与外部工具 ----
    lines.append('## 4. CI 与外部工具\n')
    lines.append('| 组件 | 当前版本 | 引用文件 | 说明 |')
    lines.append('|------|---------|----------|------|')
    lines.append(
        f'| ffmpeg-kit Windows 原生库 (`{info["ffmpeg_bundle"]}`) | `{info["ffmpeg_builder"]}` | '
        '`.github/workflows/build.yml` / `.gitea/workflows/build.yml` | '
        'Windows 产物内置的 libffmpegkit.dll（构建期下载 → 短名重打包 → code asset）|'
    )
    for name, entry in actions.items():
        ref = ' / '.join(f'`{r}`' for r in entry['refs'])
        desc = ACTION_DESCS.get(name, '第三方 Action')
        lines.append(f'| {name} | `{entry["version"]}` | {ref} | {desc} |')
    lines.append('')

    lines.append('---\n')
    lines.append('## 如何刷新本文档\n')
    lines.append('运行脚本重新查询 pub.dev / Google Maven / Maven Central / Gradle 版本服务并生成：\n')
    lines.append('```bash')
    lines.append('python .build/query_all_versions.py')
    lines.append('```\n')
    lines.append('也可以直接访问对应元数据：\n')
    lines.append('- Flutter 依赖：`https://pub.dev/api/packages/<package>`')
    lines.append('- Android Gradle Plugin / desugar_jdk_libs：[Google Maven](https://dl.google.com/dl/android/maven2/) 的 `maven-metadata.xml`')
    lines.append('- Kotlin：[Maven Central](https://repo1.maven.org/maven2/) 的 `maven-metadata.xml`')
    lines.append('- Gradle：`https://services.gradle.org/versions/all`')
    return format_markdown('\n'.join(lines))


def main():
    info = collect_project_info()
    pub_order, pub_refs, pub_types = collect_pub_deps()
    actions = collect_actions()

    print(f'查询 {len(pub_order)} 个 Flutter 依赖的元数据 ...')
    pub_latest = {}
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(fetch_pub, pkg) for pkg, _v in pub_order]
        current_of = dict(pub_order)
        for future in as_completed(futures):
            pkg, versions = future.result()
            if versions:
                pub_latest[pkg] = compute_latest(current_of[pkg], versions)
            print(f'  [{"OK" if versions else "FAIL"}] {pkg}')

    print('\n查询 Android 构建链的元数据 ...')
    build_sources = {
        'Gradle': ('gradle', None, None),
        'Android Gradle Plugin': ('maven', GOOGLE_MAVEN, ('com.android.tools.build', 'gradle')),
        'Kotlin Gradle Plugin': ('maven', MAVEN_CENTRAL, ('org.jetbrains.kotlin', 'kotlin-gradle-plugin')),
        'Kotlin Stdlib': ('maven', MAVEN_CENTRAL, ('org.jetbrains.kotlin', 'kotlin-stdlib')),
        'Desugar JDK Libs': ('maven', GOOGLE_MAVEN, ('com.android.tools', 'desugar_jdk_libs')),
    }
    current_build = {
        'Gradle': info['gradle'],
        'Android Gradle Plugin': info['agp'],
        'Kotlin Gradle Plugin': info['kotlin'],
        'Kotlin Stdlib': info['kotlin_stdlib'],
        'Desugar JDK Libs': info['desugar'],
    }
    build_latest = {}
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = {}
        for name, (kind, base, coords) in build_sources.items():
            if kind == 'gradle':
                futures[executor.submit(fetch_gradle)] = name
            else:
                futures[executor.submit(fetch_maven, base, coords[0], coords[1])] = name
        for future in as_completed(futures):
            name = futures[future]
            versions = future.result()
            if versions:
                build_latest[name] = compute_latest(current_build[name], versions)
            print(f'  [{"OK" if versions else "FAIL"}] {name}')

    output = build_markdown(info, pub_order, pub_refs, pub_types, pub_latest, build_latest, actions)
    OUTPUT.write_text(output, encoding='utf-8', newline='\n')
    print(f'\n已写入 {OUTPUT} （{len(output)} 字节）')


if __name__ == '__main__':
    main()
