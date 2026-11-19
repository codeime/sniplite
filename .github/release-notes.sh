#!/bin/sh
# Writes the notes of a sniplite for Mac release, in English and Chinese, to notes.md:
# what is new (from macos/release-notes/<version>.en.md and .zh.md, when they exist), then how to install.
set -e
V="$1"
NEW_EN="macos/release-notes/$V.en.md"
NEW_ZH="macos/release-notes/$V.zh.md"
{
  echo "## English"
  echo
  if [ -f "$NEW_EN" ]; then echo "### What's new"; echo; cat "$NEW_EN"; echo; fi
  cat <<NOTES
### Install

macOS 14 or later, Apple Silicon and Intel.

1. Download \`sniplite_${V}_macos.zip\`, unzip it and move \`sniplite.app\` to Applications.
2. It is not notarized, so remove the quarantine flag once:
   \`xattr -dr com.apple.quarantine "/Applications/sniplite.app"\`
3. Open it and allow Screen Recording and Accessibility on its permissions page.

Already on 1.0.2 or later? Settings › Updates installs it for you.

For Windows, download sniplite from the original repository: https://github.com/MrTangLuyao/sniplite/releases

## 中文

NOTES
  if [ -f "$NEW_ZH" ]; then echo "### 更新内容"; echo; cat "$NEW_ZH"; echo; fi
  cat <<NOTES
### 安装

需要 macOS 14 或更高版本，支持 Apple 芯片和 Intel。

1. 下载 \`sniplite_${V}_macos.zip\`，解压后把 \`sniplite.app\` 移到"应用程序"。
2. 没有经过苹果公证，运行一次下面的命令去掉隔离标记：
   \`xattr -dr com.apple.quarantine "/Applications/sniplite.app"\`
3. 打开后在权限页允许屏幕录制和辅助功能。

已经在用 1.0.2 或更新的版本？在"设置 › 更新"里可以直接更新。

Windows 版请到原仓库下载：https://github.com/MrTangLuyao/sniplite/releases
NOTES
} > notes.md
