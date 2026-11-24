import Foundation

/// The texts of the app. English and Simplified / Traditional Chinese; the language follows
/// the system unless one is picked in Settings.
enum L {
    enum Lang: String, CaseIterable { case system, en, zhHans = "zh-Hans", zhHant = "zh-Hant" }

    static var current: Lang {
        let pick = Lang(rawValue: Prefs.shared.language) ?? .system
        if pick != .system { return pick }
        let pref = Locale.preferredLanguages.first ?? "en"
        if pref.hasPrefix("zh-Hant") || pref.hasPrefix("zh-TW") || pref.hasPrefix("zh-HK") { return .zhHant }
        if pref.hasPrefix("zh") { return .zhHans }
        return .en
    }

    static func t(_ key: String) -> String {
        let table: [String: String]
        switch current {
        case .zhHans: table = zhHans
        case .zhHant: table = zhHant
        default: return en[key] ?? key
        }
        return table[key] ?? en[key] ?? key
    }

    static let en: [String: String] = [
        "quickTab": "Quick capture",
        "quickEnable": "Quick capture (⇧F1)",
        "noticePosition": "Notice position", "posTopRight": "Top right", "posBottomRight": "Bottom right", "posTopCenter": "Top center", "posCenter": "Center",
        "quickNotice": "Show a notice after a quick capture", "quickNoticeDetail": "The menu bar icon flashes either way; this adds a banner with the file, a click shows it.",
        "quickCapture": "Quick capture to a file", "quickSaved": "Screenshot saved", "showInFinder": "Click to show it in Finder", "quickFolder": "Quick capture saves to", "quickFolderDetail": "⇧F1: the screen under the mouse, straight to a file.", "chooseFolder": "Choose", "theme": "Theme", "themeSystem": "Same as macOS", "themeLight": "Light", "themeDark": "Dark",
        "capture": "Capture", "pinClipboard": "Pin from clipboard", "togglePins": "Hide / show pins",
        "ocrCapture": "Capture and read text", "ocrCopyCapture": "Capture and copy text",
        "settings": "Settings…", "about": "About sniplite", "quit": "Quit sniplite",
        "rect": "Rectangle", "sizeTip": "Size (or the wheel)", "opacityTip": "Opacity", "mosaicRect": "Hide a box", "mosaicBrush": "Hide with a brush", "mosaicSwatch": "Mosaic (or pick a color to cover)", "ellipse": "Ellipse", "line": "Line", "arrow": "Arrow", "pen": "Pen",
        "marker": "Marker", "mosaic": "Hide (mosaic / color)", "text": "Text", "number": "Number",
        "undo": "Undo (⌘Z)", "redo": "Redo (⇧⌘Z)", "pin": "Pin to screen (⌘T)", "save": "Save (⌘S)",
        "close": "Cancel (Esc)", "ok": "Copy (Enter)", "ocr": "Read text (⌘O)", "ocrCopy": "Copy text (⇧⌘C)",
        "copy": "Copy", "editPin": "Edit", "close.pin": "Close", "closeAll": "Close all pins", "onTop": "Always on top",
        "readText": "Read text", "imageCopied": "Image copied", "colorCopied": "Color copied", "textCopied": "Text copied", "noText": "No text found", "later": "Later",
        "hotkeys": "Shortcuts", "general": "General", "language": "Language", "langSystem": "Same as system",
        "launchAtLogin": "Open at login", "pinTop": "Pins stay on top",
        "recordHint": "Click, then press keys", "offState": "Off", "goTurnOn": "Turn on ›", "aboutTab": "About", "versionFmt": "Version %@", "softwareUpdate": "Software update", "checkUpdates": "Check for Updates", "updInstall": "Download and Install", "releaseNotes": "Release notes ›", "secUpdate": "Updates", "secLinks": "Links", "autoCheck": "Check for updates automatically", "autoCheckDetail": "Only the version number is asked from GitHub.", "checkEvery": "How often", "everyDay": "Every day", "everyWeek": "Every week", "everyMonth": "Every month", "updNever": "Not checked yet.", "updLastChecked": "Last checked %@.", "updChecking": "Checking…", "updUpToDate": "sniplite is up to date.", "updAvailable": "Version %@ is available.", "updDownloading": "Downloading… %d%%", "updInstalling": "Installing; sniplite opens again in a moment…", "updFailed": "Could not update: %@", "updCheckFailed": "Could not check: %@", "updNoRelease": "no release found", "updDownloadFailed": "the download failed", "updUnzipFailed": "the download could not be opened", "updNotValid": "the download is not a valid sniplite", "updMenu": "Update to %@…", "homepage": "Project page", "feedback": "Report an issue", "originalWin": "Original (Windows)", "license": "License", "aboutFoot": "sniplite for Mac is based on sniplite by MrTangLuyao, and open source under the MIT License.", "desktopName": "Desktop", "currentVersion": "This is version %@.", "hkFoot": "Click a shortcut, then press the new keys. Delete clears it; Esc keeps the old one.", "secCapture": "Capture", "secPins": "Pins", "secApp": "App", "secNotice": "Notice", "permFoot": "Allowed once, they can be changed in System Settings › Privacy & Security.", "none": "None",
        "langRestart": "The new language is used from the next capture; restart for the menu.",
        "hkConflict": "This shortcut could not be registered; another app may be using it.",
        "copyColor": "C: copy color", "ocrTitle": "Text", "copyAll": "Copy all", "copyMarkdown": "Copy as Markdown",
        "reading": "Reading text…", "readingSlow": "One moment; the first time takes longer", "ocrFailed": "Text recognition failed", "noticePositionDetail": "For every notice: quick capture, copying, text recognition.",
        "permissions": "Permissions", "permMissing": "Not allowed yet: %@", "listSep": ", ", "ocrTitle2": "Text recognition", "ocrDetail": "F4 / ⇧F4 and the toolbar buttons; runs on this Mac.", "screenRecording": "Screen Recording", "granted": "Allowed", "grant": "Allow…",
        "accessibility": "Accessibility", "deviceControl": "Device Control and Data Access",
        "whyScreen": "Lets sniplite read the screen; capturing needs it.", "whyAX": "Makes the F1–F12 shortcuts work, and picks buttons and fields inside windows.", "optional": "Optional", "openPane": "Allow…",
        "permDrag": "After “Allow…”, drag the sniplite icon under System Settings into the list and turn it on.",
        "permTitle2": "Welcome to sniplite", "permSubtitle": "Allow the permissions below once, and press F1 to capture.",
        "required": "Required", "done": "Done", "autoCloseIn": "Closes in %ds",
        "permDone": "All set.", "permRestart": "All set. Restarting sniplite to use Screen Recording…", "dragBig": "Drag sniplite into the list", "step1": "Hold this row", "stepUp": "Drag to the list above", "stepLeft": "Drag to the list on the left", "stepRight": "Drag to the list on the right", "step3": "Turn it on",
    ]

    static let zhHans: [String: String] = [
        "quickTab": "快速截图",
        "quickEnable": "快速截图（⇧F1）",
        "noticePosition": "提示位置", "posTopRight": "右上", "posBottomRight": "右下", "posTopCenter": "中上", "posCenter": "居中",
        "quickNotice": "快速截图后显示提示", "quickNoticeDetail": "菜单栏图标都会闪一下；打开后还会显示带文件位置的横幅，点击可在访达中显示。",
        "quickCapture": "快速截图（存为文件）", "quickSaved": "截图已保存", "showInFinder": "点击在访达中显示", "quickFolder": "快速截图保存到", "quickFolderDetail": "⇧F1：把鼠标所在的屏幕直接存成文件。", "chooseFolder": "选择", "theme": "主题", "themeSystem": "跟随系统", "themeLight": "浅色", "themeDark": "深色",
        "capture": "截图", "pinClipboard": "贴图（剪贴板）", "togglePins": "隐藏 / 显示贴图",
        "ocrCapture": "截图并识别文字", "ocrCopyCapture": "截图并复制文字",
        "settings": "设置…", "about": "关于 sniplite", "quit": "退出 sniplite",
        "rect": "矩形", "sizeTip": "大小（也可以用滚轮）", "opacityTip": "透明度", "mosaicRect": "框选打码", "mosaicBrush": "画笔打码", "mosaicSwatch": "马赛克（也可以选颜色遮挡）", "ellipse": "椭圆", "line": "直线", "arrow": "箭头", "pen": "画笔",
        "marker": "记号笔", "mosaic": "打码（马赛克 / 色块）", "text": "文字", "number": "序号",
        "undo": "撤销 (⌘Z)", "redo": "重做 (⇧⌘Z)", "pin": "贴到屏幕 (⌘T)", "save": "保存 (⌘S)",
        "close": "取消 (Esc)", "ok": "复制 (Enter)", "ocr": "识别文字 (⌘O)", "ocrCopy": "复制文字 (⇧⌘C)",
        "copy": "复制", "editPin": "编辑", "close.pin": "关闭", "closeAll": "关闭所有贴图", "onTop": "置顶",
        "readText": "识别文字", "imageCopied": "图片已复制", "colorCopied": "颜色已复制", "textCopied": "文字已复制", "noText": "没有识别到文字", "later": "稍后",
        "hotkeys": "快捷键", "general": "通用", "language": "语言", "langSystem": "跟随系统",
        "launchAtLogin": "登录时打开", "pinTop": "贴图置顶",
        "recordHint": "点击后按下按键", "offState": "未开启", "goTurnOn": "去开启 ›", "aboutTab": "关于", "versionFmt": "版本 %@", "softwareUpdate": "软件更新", "checkUpdates": "检查更新", "updInstall": "下载并安装", "releaseNotes": "更新说明 ›", "secUpdate": "更新", "secLinks": "链接", "autoCheck": "自动检查更新", "autoCheckDetail": "只向 GitHub 查询版本号。", "checkEvery": "检查频率", "everyDay": "每天", "everyWeek": "每周", "everyMonth": "每月", "updNever": "尚未检查。", "updLastChecked": "上次检查：%@。", "updChecking": "正在检查…", "updUpToDate": "已是最新版本。", "updAvailable": "有新版本 %@。", "updDownloading": "正在下载… %d%%", "updInstalling": "正在安装，sniplite 稍后会重新打开…", "updFailed": "更新失败：%@", "updCheckFailed": "检查失败：%@", "updNoRelease": "没有找到发布版本", "updDownloadFailed": "下载失败", "updUnzipFailed": "无法打开下载的文件", "updNotValid": "下载的文件不是有效的 sniplite", "updMenu": "更新到 %@…", "homepage": "项目主页", "feedback": "反馈问题", "originalWin": "原版（Windows）", "license": "许可证", "aboutFoot": "sniplite for Mac 源自 MrTangLuyao 的 sniplite，以 MIT 许可证开源。", "desktopName": "桌面", "currentVersion": "当前版本 %@。", "hkFoot": "点一下快捷键，再按下新的按键。Delete 清除，Esc 保留原来的。", "secCapture": "截图", "secPins": "贴图", "secApp": "应用", "secNotice": "提示", "permFoot": "只需授权一次，之后可在“系统设置 › 隐私与安全性”中更改。", "none": "无",
        "langRestart": "新语言从下次截图开始生效；菜单需重启后更新。",
        "hkConflict": "无法注册这个快捷键，可能已被其他应用占用。",
        "copyColor": "C：复制颜色", "ocrTitle": "文字", "copyAll": "全部复制", "copyMarkdown": "复制为 Markdown",
        "reading": "正在识别文字…", "readingSlow": "请稍候，首次识别会慢一些", "ocrFailed": "文字识别失败", "noticePositionDetail": "所有提示统一显示在这里：快速截图、复制、文字识别。",
        "permissions": "权限", "permMissing": "尚未授权：%@", "listSep": "、", "ocrTitle2": "文字识别", "ocrDetail": "F4 / ⇧F4 和工具栏按钮，在本机运行。", "screenRecording": "屏幕录制", "granted": "已允许", "grant": "去授权…",
        "accessibility": "辅助功能", "deviceControl": "设备控制和数据访问",
        "whyScreen": "用来读取屏幕画面，截图离不开它。", "whyAX": "让 F1–F12 快捷键生效，并识别窗口里的按钮、输入框等元素。", "optional": "可选", "openPane": "去开启…",
        "permDrag": "点“去开启”后，把系统设置下方的 sniplite 图标拖进列表，再打开开关。",
        "permTitle2": "欢迎使用 sniplite", "permSubtitle": "授予下面的权限后，按 F1 即可截图。只需设置一次。",
        "required": "必需", "done": "完成", "autoCloseIn": "%d 秒后自动关闭",
        "permDone": "全部完成。", "permRestart": "全部完成，sniplite 将重新启动以启用屏幕录制。", "dragBig": "把 sniplite 拖进列表", "step1": "按住下面这一行", "stepUp": "拖到上方列表", "stepLeft": "拖到左侧列表", "stepRight": "拖到右侧列表", "step3": "打开开关",
    ]

    static let zhHant: [String: String] = [
        "quickTab": "快速截圖",
        "quickEnable": "快速截圖（⇧F1）",
        "noticePosition": "提示位置", "posTopRight": "右上", "posBottomRight": "右下", "posTopCenter": "中上", "posCenter": "置中",
        "quickNotice": "快速截圖後顯示提示", "quickNoticeDetail": "選單列圖示都會閃一下；開啟後還會顯示帶檔案位置的橫幅，點一下可在 Finder 中顯示。",
        "quickCapture": "快速截圖（存成檔案）", "quickSaved": "截圖已儲存", "showInFinder": "點擊在 Finder 中顯示", "quickFolder": "快速截圖儲存到", "quickFolderDetail": "⇧F1：把滑鼠所在的螢幕直接存成檔案。", "chooseFolder": "選擇", "theme": "主題", "themeSystem": "跟隨系統", "themeLight": "淺色", "themeDark": "深色",
        "capture": "截圖", "pinClipboard": "貼圖（剪貼簿）", "togglePins": "隱藏 / 顯示貼圖",
        "ocrCapture": "截圖並辨識文字", "ocrCopyCapture": "截圖並複製文字",
        "settings": "設定…", "about": "關於 sniplite", "quit": "結束 sniplite",
        "rect": "矩形", "sizeTip": "大小（也可以用滾輪）", "opacityTip": "透明度", "mosaicRect": "框選打碼", "mosaicBrush": "畫筆打碼", "mosaicSwatch": "馬賽克（也可以選顏色遮擋）", "ellipse": "橢圓", "line": "直線", "arrow": "箭頭", "pen": "畫筆",
        "marker": "螢光筆", "mosaic": "打碼（馬賽克 / 色塊）", "text": "文字", "number": "序號",
        "undo": "復原 (⌘Z)", "redo": "重做 (⇧⌘Z)", "pin": "貼到螢幕 (⌘T)", "save": "儲存 (⌘S)",
        "close": "取消 (Esc)", "ok": "複製 (Enter)", "ocr": "辨識文字 (⌘O)", "ocrCopy": "複製文字 (⇧⌘C)",
        "copy": "複製", "editPin": "編輯", "close.pin": "關閉", "closeAll": "關閉所有貼圖", "onTop": "置頂",
        "readText": "辨識文字", "imageCopied": "圖片已複製", "colorCopied": "顏色已複製", "textCopied": "文字已複製", "noText": "沒有辨識到文字", "later": "稍後",
        "hotkeys": "快速鍵", "general": "一般", "language": "語言", "langSystem": "跟隨系統",
        "launchAtLogin": "登入時打開", "pinTop": "貼圖置頂",
        "recordHint": "點一下再按下按鍵", "offState": "未開啟", "goTurnOn": "去開啟 ›", "aboutTab": "關於", "versionFmt": "版本 %@", "softwareUpdate": "軟體更新", "checkUpdates": "檢查更新", "updInstall": "下載並安裝", "releaseNotes": "更新說明 ›", "secUpdate": "更新", "secLinks": "連結", "autoCheck": "自動檢查更新", "autoCheckDetail": "只向 GitHub 查詢版本號。", "checkEvery": "檢查頻率", "everyDay": "每天", "everyWeek": "每週", "everyMonth": "每月", "updNever": "尚未檢查。", "updLastChecked": "上次檢查：%@。", "updChecking": "正在檢查…", "updUpToDate": "已是最新版本。", "updAvailable": "有新版本 %@。", "updDownloading": "正在下載… %d%%", "updInstalling": "正在安裝，sniplite 稍後會重新開啟…", "updFailed": "更新失敗：%@", "updCheckFailed": "檢查失敗：%@", "updNoRelease": "沒有找到發佈版本", "updDownloadFailed": "下載失敗", "updUnzipFailed": "無法開啟下載的檔案", "updNotValid": "下載的檔案不是有效的 sniplite", "updMenu": "更新到 %@…", "homepage": "專案主頁", "feedback": "回報問題", "originalWin": "原版（Windows）", "license": "授權", "aboutFoot": "sniplite for Mac 源自 MrTangLuyao 的 sniplite，以 MIT 授權開源。", "desktopName": "桌面", "currentVersion": "目前版本 %@。", "hkFoot": "點一下快速鍵，再按下新的按鍵。Delete 清除，Esc 保留原來的。", "secCapture": "截圖", "secPins": "貼圖", "secApp": "App", "secNotice": "提示", "permFoot": "只需授權一次，之後可在「系統設定 › 隱私權與安全性」中更改。", "none": "無",
        "langRestart": "新語言從下次截圖開始生效；選單需重新啟動後更新。",
        "hkConflict": "無法註冊這個快速鍵，可能已被其他 App 佔用。",
        "copyColor": "C：複製顏色", "ocrTitle": "文字", "copyAll": "全部複製", "copyMarkdown": "複製為 Markdown",
        "reading": "正在辨識文字…", "readingSlow": "請稍候，首次辨識會慢一些", "ocrFailed": "文字辨識失敗", "noticePositionDetail": "所有提示統一顯示在這裡：快速截圖、複製、文字辨識。",
        "permissions": "權限", "permMissing": "尚未授權：%@", "listSep": "、", "ocrTitle2": "文字辨識", "ocrDetail": "F4 / ⇧F4 和工具列按鈕，在本機執行。", "screenRecording": "螢幕錄製", "granted": "已允許", "grant": "去授權…",
        "accessibility": "輔助使用", "deviceControl": "裝置控制和資料取用",
        "whyScreen": "截圖一定要有。", "whyAX": "讓 F1–F12 快速鍵生效，並辨識視窗裡的按鈕、輸入框等元素。", "optional": "可選", "openPane": "去開啟…",
        "permDrag": "點「去開啟」後，把系統設定下方的 sniplite 圖示拖進列表，再打開開關。",
        "permTitle2": "歡迎使用 sniplite", "permSubtitle": "授予下面的權限後，按 F1 即可截圖。只需設定一次。",
        "required": "必需", "done": "完成", "autoCloseIn": "%d 秒後自動關閉",
        "permDone": "全部完成。", "permRestart": "全部完成，正在重新啟動 sniplite 以啟用螢幕錄製…", "dragBig": "把 sniplite 拖進列表", "step1": "按住下面這一行", "stepUp": "拖到上方列表", "stepLeft": "拖到左側列表", "stepRight": "拖到右側列表", "step3": "打開開關",
    ]
}
