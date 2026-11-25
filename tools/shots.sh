#!/bin/bash
# 给某一套界面风格在模拟器上截一整套图（各个状态，浅色 + 深色），再拼一张总览。
# 用法：tools/shots.sh <模拟器 UDID> <风格 a|c|d|e> <输出目录> <编译缓存目录> [只截这些状态…]
#   例：tools/shots.sh $UDID d /tmp/shots-d /tmp/dd-d            全套
#       tools/shots.sh $UDID d /tmp/shots-d /tmp/dd-d 02 05       只截 02、05 两张（浅色），改一处看一处时用
# 输出：<输出目录>/NN-名字.png（原始大小）、small/ 里是缩小一半的（先看这个，省事），overview.png 是总览
# 各状态靠启动参数摆出来（见 SearchOnly/UIShared.swift 里的 UIDemo），不用手点
set -uo pipefail
UDID=$1; STYLE=$2; OUT=$3; DD=$4; shift 4
ONLY=("$@")
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# app 的 bundle id 从工程设置里读（Signing.xcconfig / Local.xcconfig）
APP=$(xcodebuild -project "$ROOT/SearchOnly.xcodeproj" -target SearchOnly -configuration Debug -showBuildSettings 2>/dev/null | awk '$1=="PRODUCT_BUNDLE_IDENTIFIER"{print $3; exit}')
mkdir -p "$OUT/small"

echo "== 编译"
if ! xcodebuild -project "$ROOT/SearchOnly.xcodeproj" -scheme SearchOnly -configuration Debug \
     -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DD" build > "$OUT/build.log" 2>&1; then
  grep -E "error:" "$OUT/build.log" | sort -u | head -40
  echo "编译失败（完整日志：$OUT/build.log）"; exit 1
fi
grep -E "warning:" "$OUT/build.log" | grep -E "Design[A-D]|UIShared|UIStyle" | sort -u | head -20

xcrun simctl bootstatus "$UDID" -b > /dev/null 2>&1
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 > /dev/null 2>&1
xcrun simctl install "$UDID" "$DD/Build/Products/Debug-iphonesimulator/SearchOnly.app" || exit 1

RECENT='("咖啡", "露营装备", "北京周末去哪", "手冲咖啡豆推荐", "租房避坑")'
TODAY=$(date +%F)

wanted() { # 这张要不要截
  [ ${#ONLY[@]} -eq 0 ] && return 0
  for n in "${ONLY[@]}"; do [[ "$1" == "$n"* ]] && return 0; done
  return 1
}

shot() { # 名字 等几秒 启动参数…
  local name=$1 wait=$2; shift 2
  wanted "$name" || return 0
  xcrun simctl launch --terminate-running-process "$UDID" $APP -xso.uiStyle "$STYLE" "$@" > /dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" > /dev/null 2>&1
  sips -Z 1300 "$OUT/$name.png" --out "$OUT/small/$name.png" > /dev/null 2>&1
  echo "  $name"
}

# 用了多久存在 xso.usagePlatformSeconds 里（键是 xhs），值要写成 XML 属性列表才是数字
secs() { echo "<dict><key>xhs</key><real>$1</real></dict>"; }
IN=(-xso.loggedIn YES -xso.usagePlatformSeconds "$(secs 720)" -xso.usageDay "$TODAY")   # 已登录：显示原生首页；今天用了 12 分钟（后面的参数会盖掉前面的）
USAGE=(-xso.usageLimit 30 -xso.usagePlatformSeconds "$(secs 1260)" -xso.usageDay "$TODAY")   # 今天用了 21 分钟，上限 30

echo "== 浅色"
xcrun simctl ui "$UDID" appearance light
shot 01-home-keyboard   5 "${IN[@]}" -xso.recentSearches "$RECENT"                                   # 刚打开：键盘弹着，有最近搜索和提示卡
shot 02-home-idle       5 "${IN[@]}" -xso.recentSearches "$RECENT" -uiDemo home-idle                 # 收起键盘：能看到底栏
shot 03-home-typing     5 "${IN[@]}" -xso.recentSearches "$RECENT" -xso.recommendationTipDone YES -uiDemoQuery "手冲咖啡"   # 输入了字
shot 04-home-empty      5 "${IN[@]}" -xso.recentSearches "()" -xso.recommendationTipDone YES -uiDemo home-idle             # 最空的样子：没有最近搜索、提示卡已关
shot 05-home-searching  5 "${IN[@]}" -xso.recentSearches "$RECENT" -xso.recommendationTipDone YES -uiDemo searching       # 「正在打开…」
shot 06-settings        5 "${IN[@]}" "${USAGE[@]}" -uiDemo settings                                   # 设置页顶部
shot 07-settings-bottom 5 "${IN[@]}" "${USAGE[@]}" -uiDemo settings-bottom                            # 设置页滑到底
shot 08-messages        6 "${IN[@]}" -uiDemo messages                                                 # 消息页：私信
shot 09-notifications   6 "${IN[@]}" -uiDemo notifications                                            # 消息页：评论和通知
shot 10-reminder        5 "${IN[@]}" -xso.usageLimit 30 -uiDemo reminder                              # 使用时间提醒
shot 11-login           7 -xso.loggedIn NO -uiDemo login                                              # 扫码登录提示（底下是小红书登录页）
shot 13-loading         7 "${IN[@]}" -uiDemo loading                                                  # 网页顶上的进度条
shot 14-results         7 "${IN[@]}" -uiDemo results                                                  # 搜索结果页：顶栏（返回 + 搜的词）、占位的笔记卡片、底栏

echo "== 深色"
xcrun simctl ui "$UDID" appearance dark
shot 21-home-keyboard-dark 5 "${IN[@]}" -xso.recentSearches "$RECENT"
shot 22-home-idle-dark     5 "${IN[@]}" -xso.recentSearches "$RECENT" -uiDemo home-idle
shot 26-settings-dark      5 "${IN[@]}" "${USAGE[@]}" -uiDemo settings
shot 28-messages-dark      6 "${IN[@]}" -uiDemo messages
shot 30-reminder-dark      5 "${IN[@]}" -xso.usageLimit 30 -uiDemo reminder
shot 34-results-dark       7 "${IN[@]}" -uiDemo results
xcrun simctl ui "$UDID" appearance light
xcrun simctl terminate "$UDID" $APP > /dev/null 2>&1

if [ ${#ONLY[@]} -eq 0 ]; then
  swift "$ROOT/tools/contact-sheet.swift" "$OUT/overview.png" 6 "$OUT"/[0-9]*.png
fi
echo "完成：$OUT"
