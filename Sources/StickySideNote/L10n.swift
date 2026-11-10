import Foundation

/// Interface text in English and Simplified Chinese. Follows the system language;
/// STICKY_LANG=en or STICKY_LANG=zh overrides it (used for screenshots).
enum L10n {
    static let isChinese: Bool = {
        if let forced = ProcessInfo.processInfo.environment["STICKY_LANG"] {
            return forced.hasPrefix("zh")
        }
        return Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }()

    private static func pick(_ en: String, _ zh: String) -> String { isChinese ? zh : en }

    static let hintIdle = pick("Click to copy · Double-click to edit", "单击复制 · 双击编辑")
    static let hintCopied = pick("✓ Copied", "✓ 已复制")
    static let hintEditing = pick("Esc or click away to save", "Esc 或点别处保存")
    static let welcome = pick("Hover to read · Click to copy · Double-click to edit · Right-click for colour or delete",
                              "悬停看全文 · 单击复制 · 双击编辑 · 右键换色或删除")

    static let newNote = pick("New note", "新建便签")
    static let newNoteFromClipboard = pick("New note from clipboard", "从剪贴板新建便签")
    static let deleteNote = pick("Delete note", "删除便签")
    static let showAll = pick("Show all notes", "显示全部便签")
    static let hideAll = pick("Hide all notes", "隐藏全部便签")
    static let moveTo = pick("Move to", "移动到")
    static let left = pick("Left", "左侧")
    static let right = pick("Right", "右侧")
    static let launchAtLogin = pick("Launch at login", "开机自动启动")
    static let quit = pick("Quit", "退出")
}
