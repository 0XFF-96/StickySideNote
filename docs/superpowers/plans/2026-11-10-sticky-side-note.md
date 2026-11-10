# StickySideNote Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一个 Mac 菜单栏 App，把彩色便签常驻贴在屏幕左边缘：悬停展开、单击复制、双击编辑、右键换色或删除。

**Architecture:** 一个 Swift Package，两个 target。`StickyCore`（纯 Foundation/Combine，可单元测试）放数据模型、存储、排版计算和交互状态机；`StickySideNote`（可执行，AppKit + SwiftUI）放一个无边框、不激活的 `NSPanel`、SwiftUI 视图和菜单栏。面板平时只有便签列那么大（36 pt 宽），悬停或编辑时才加宽，所以窄带以外的点击天然穿透。一个脚本把可执行文件装配成 `.app` 并安装到 `/Applications`。

**Tech Stack:** Swift 6.4 工具链（语言模式 v5）、SwiftPM、SwiftUI、AppKit、ServiceManagement、XCTest。无第三方依赖。

**Spec:** `docs/superpowers/specs/2026-11-10-sticky-side-note-design.md`，可交互原型 `docs/superpowers/specs/prototype.html`。外观和手感以原型为准，行为以 spec 为准。

## Global Constraints

- 最低系统 macOS 14；不引入第三方依赖。
- 悬停和单击复制不得让前台 App 失去键盘焦点；只有编辑时面板才成为 key window。
- 便签窄带以外的区域鼠标事件必须穿透。
- 颜色、圆角、投影、动效只用 spec 5.8 节的令牌值：圆角只有 6 / 8 / 16 / 24 pt；动效 180 ms、`cubic-bezier(.16,1,.3,1)`；禁止回弹、弹簧、过冲、缩放；不用渐变、毛玻璃。
- 便签文字色 `#020617`；花瓣色上不用白字。
- 字体 DM Sans，缺失时回落系统字体；中文走系统苹方。
- 界面文字为简体中文，不用 emoji、不用感叹号。固定文案：`单击复制 · 双击编辑`、`✓ 已复制`、`Esc 或点别处保存`、`删除便签`、`新建便签`、`隐藏全部便签` / `显示全部便签`、`开机自动启动`、`退出`。
- 存储路径 `~/Library/Application Support/StickySideNote/notes.json`，原子写入。
- 不放  logo。
- 每个任务结束时提交一次；提交信息末尾加 `Co-Authored-By: Claude <noreply@anthropic.com>`。

## Review Focus

1. **编辑到一半时退出 App、点"隐藏全部"或面板失去焦点**：正在输入的文字应当保存，不能丢。（任务 6 的测试 `testCommitOnResign`，任务 8 手动验证）
2. **`notes.json` 损坏或是空文件**：不崩溃，把坏文件改名备份，从空列表启动，且不覆盖备份。（任务 2 的测试）
3. **首字符是 emoji、组合字符，或笔记以空格/换行开头**：小条上显示第一个可见字符的完整字形。（任务 1 的测试）
4. **屏幕变化**：换分辨率、拔掉外接屏、Dock 移到左边、便签多到放不下——每张便签都仍然可见可点。（任务 3 的测试，任务 8 手动验证）
5. **很长的笔记，或鼠标沿左边缘快速划过**：展开卡片高度不超过屏幕 60% 且可滚动、不伸出屏幕底部；快速划过不闪烁。（任务 3 的测试 `testCardShiftsUpNearBottom`，任务 5 手动验证）

---

## File Structure

```
Package.swift
.gitignore
Sources/StickyCore/Note.swift          Note、NoteColor、首字符、复制文本
Sources/StickyCore/NoteStore.swift     读写 notes.json、增删改、下一个颜色
Sources/StickyCore/RailLayout.swift    小条尺寸、能否新建、展开卡片位置
Sources/StickyCore/RailModel.swift     交互状态机（悬停、复制、编辑、隐藏）
Sources/StickySideNote/main.swift      启动 NSApplication
Sources/StickySideNote/AppDelegate.swift   装配、菜单栏、开机自启动
Sources/StickySideNote/RailPanel.swift     NSPanel 子类 + PanelController（定位、改尺寸）
Sources/StickySideNote/Theme.swift         令牌：颜色、圆角、投影、动画、字体
Sources/StickySideNote/RailView.swift      便签列 + "+"
Sources/StickySideNote/NoteView.swift      单张便签：收起、展开、编辑
Sources/StickySideNote/HoverTracker.swift  NSTrackingArea(.activeAlways) 的 SwiftUI 包装
Sources/StickySideNote/NoteMenu.swift      右键菜单
Tests/StickyCoreTests/*.swift
Resources/Info.plist
Resources/Fonts/DMSans-VariableFont_opsz_wght.ttf
scripts/install.sh
```

---

### Task 1: 工程骨架与 Note 模型

**Files:**
- Create: `Package.swift`, `.gitignore`, `Sources/StickyCore/Note.swift`, `Sources/StickySideNote/main.swift`（暂时只 `print("StickySideNote")`）
- Test: `Tests/StickyCoreTests/NoteTests.swift`

**Interfaces:**
- Produces:
  - `public enum NoteColor: String, Codable, CaseIterable { case sky, cyan, lavender, coral, gold, sun }`，`public var hex: String`（`#a7cde8`、`#4dd0cf`、`#c9bfe5`、`#e59fb1`、`#f2b33c`、`#f4d86b`），`public var next: NoteColor`（按 `allCases` 顺序循环）
  - `public struct Note: Codable, Identifiable, Equatable { public let id: UUID; public var text: String; public var color: NoteColor; public let createdAt: Date; public init(id: UUID = UUID(), text: String, color: NoteColor, createdAt: Date = Date()) }`
  - `public var cap: String`（Note 上）：去掉首尾空白和换行后的第一个 `Character`，`uppercased()`；为空时返回 `"·"`
  - `public var copyText: String`：`text` 去掉首尾空白和换行

- [ ] **Step 1: `git init`，写 `Package.swift` 和 `.gitignore`**

`Package.swift`：`// swift-tools-version: 6.0`，`platforms: [.macOS(.v14)]`，library target `StickyCore`，executable target `StickySideNote`（依赖 `StickyCore`），test target `StickyCoreTests`，`swiftLanguageModes: [.v5]`。`.gitignore`：`.build/`、`.superpowers/`、`.DS_Store`。

- [ ] **Step 2: 写失败的测试**

```swift
final class NoteTests: XCTestCase {
    func testCap() {
        XCTAssertEqual(Note(text: "少即是多", color: .sky).cap, "少")
        XCTAssertEqual(Note(text: "git commit", color: .sky).cap, "G")
        XCTAssertEqual(Note(text: "  \n hello", color: .sky).cap, "H")
        XCTAssertEqual(Note(text: "👨‍👩‍👧 family", color: .sky).cap, "👨‍👩‍👧")
        XCTAssertEqual(Note(text: "é", color: .sky).cap, "É")
        XCTAssertEqual(Note(text: "   ", color: .sky).cap, "·")
    }
    func testCopyText() {
        XCTAssertEqual(Note(text: "\n a b \n", color: .sky).copyText, "a b")
    }
    func testColorCycle() {
        XCTAssertEqual(NoteColor.allCases, [.sky, .cyan, .lavender, .coral, .gold, .sun])
        XCTAssertEqual(NoteColor.sky.next, .cyan)
        XCTAssertEqual(NoteColor.sun.next, .sky)
        XCTAssertEqual(NoteColor.coral.hex, "#e59fb1")
    }
    func testCodableRoundTrip() throws {
        let n = Note(text: "x", color: .gold)
        let d = try JSONEncoder().encode([n])
        XCTAssertEqual(try JSONDecoder().decode([Note].self, from: d), [n])
    }
}
```

- [ ] **Step 3: 运行 `swift test`，确认因类型未定义而失败**
- [ ] **Step 4: 实现 `Note.swift`**
- [ ] **Step 5: 运行 `swift test`，全部 PASS**
- [ ] **Step 6: 提交** `feat: package scaffold and Note model`

---

### Task 2: NoteStore 持久化

**Files:**
- Create: `Sources/StickyCore/NoteStore.swift`
- Test: `Tests/StickyCoreTests/NoteStoreTests.swift`

**Interfaces:**
- Consumes: `Note`, `NoteColor`
- Produces:
  - `public final class NoteStore: ObservableObject`
  - `public init(fileURL: URL)`：读取文件；文件不存在 → 写入一张示例便签（文字 `悬停看全文 · 单击复制 · 双击编辑 · 右键换色或删除`，颜色 `.sky`）；文件存在但解码失败（含空文件）→ 把它改名为同目录 `notes.corrupt-<unix秒>.json`，`notes = []`，此时不写新文件
  - `public static var defaultURL: URL`：`~/Library/Application Support/StickySideNote/notes.json`
  - `@Published public private(set) var notes: [Note]`（按创建顺序）
  - `@discardableResult public func add(text: String) -> Note`：颜色为最后一张的 `color.next`，没有便签时 `.sky`
  - `public func updateText(_ id: UUID, _ text: String)`、`public func setColor(_ id: UUID, _ color: NoteColor)`、`public func delete(_ id: UUID)`
  - 每次改动后立即保存：必要时创建目录，`JSONEncoder`（`dateEncodingStrategy = .iso8601`，`.prettyPrinted`），`Data.write(to:options:.atomic)`；写失败只 `NSLog`，不崩溃

- [ ] **Step 1: 写失败的测试**（每个测试用 `FileManager.default.temporaryDirectory` 下的新 UUID 目录）

```swift
func testFirstRunSeedsWelcomeNote()      // notes.count == 1，text 为上面的示例文案，文件已存在
func testAddPersistsAndCyclesColor()     // 示例(.sky) 后 add → .cyan，再 add → .lavender；新建 store 重新读取，三张内容、颜色、顺序一致
func testUpdateSetColorDeletePersist()   // 改文字、改色、删除后重新读取一致
func testCorruptFileIsBackedUp()         // 预先写入 "{not json"；init 后 notes.isEmpty，目录里有一个 notes.corrupt-*.json 且内容是 "{not json"，notes.json 不存在
func testEmptyFileIsBackedUp()           // 预先写入 0 字节文件；行为同上
func testAddAfterCorruptDoesNotTouchBackup() // 上一种情况后 add，备份文件内容不变，notes.json 含 1 张，颜色 .sky
```

- [ ] **Step 2: 运行，确认失败**
- [ ] **Step 3: 实现 `NoteStore`**
- [ ] **Step 4: 运行 `swift test`，全部 PASS**
- [ ] **Step 5: 提交** `feat: NoteStore with atomic save and corrupt-file backup`

---

### Task 3: RailLayout 排版计算

**Files:**
- Create: `Sources/StickyCore/RailLayout.swift`
- Test: `Tests/StickyCoreTests/RailLayoutTests.swift`

**Interfaces:**
- Produces:

```swift
public struct RailLayout: Equatable {
    public static let tabWidth: CGFloat = 36, tabHeight: CGFloat = 52, gap: CGFloat = 8
    public static let addWidth: CGFloat = 28, addHeight: CGFloat = 32
    public static let cardWidth: CGFloat = 268, minTabHeight: CGFloat = 14
    public static let topFraction: CGFloat = 0.13, bottomMargin: CGFloat = 8
    public static let maxCardFraction: CGFloat = 0.6

    public let tabHeight: CGFloat      // 实际小条高度
    public let gap: CGFloat            // 实际间距
    public let canAdd: Bool
    public let railHeight: CGFloat     // 所有小条 + 间距 +（canAdd 时）"+" 的总高度

    /// available = 屏幕可用高度 × (1 − topFraction) − bottomMargin
    public static func compute(noteCount: Int, available: CGFloat) -> RailLayout
    /// 第 index 张小条顶部相对便签列顶部的偏移（向下为正）
    public func tabTop(_ index: Int) -> CGFloat
    /// 展开卡片顶部的偏移：默认等于 tabTop；若 tabTop + cardHeight > available，则上移到 available − cardHeight，最小 0
    public func cardTop(index: Int, cardHeight: CGFloat, available: CGFloat) -> CGFloat
}
```

规则：`slot = 52 + 8 = 60`。`canAdd` 当且仅当 `(n + 1) × 60 + 32 ≤ available`。`n × 60 + 32 ≤ available` 时用原尺寸；否则不显示 "+"，按 `s = available / (n × 60)` 等比缩小 `tabHeight = 52s`、`gap = 8s`，`tabHeight` 不小于 14（到下限后允许超出，这是极端情况）。

- [ ] **Step 1: 写失败的测试**

```swift
func testFitsAtFullSize()   // n=4, available=700 → tabHeight 52, gap 8, canAdd true, railHeight 4*60+32
func testFullHidesAdd()     // n=11, available=700 → 原尺寸（11*60+32=692 ≤ 700）但 canAdd false（12*60+32=752）
func testShrinksToFit()     // n=20, available=700 → canAdd false，tabHeight ≈ 52*700/1200，20*(tabHeight+gap) ≤ 700.001
func testMinTabHeight()     // n=200, available=700 → tabHeight == 14
func testZeroNotes()        // n=0 → canAdd true, railHeight 32
func testTabTop()           // 原尺寸下 tabTop(2) == 120
func testCardShiftsUpNearBottom() // available=700, index 使 tabTop=600, cardHeight=260 → cardTop == 440；cardHeight=900 → 0
```

- [ ] **Step 2: 运行，确认失败**
- [ ] **Step 3: 实现**
- [ ] **Step 4: 运行 `swift test`，全部 PASS**
- [ ] **Step 5: 提交** `feat: rail layout maths`

---

### Task 4: RailModel 交互状态机

**Files:**
- Create: `Sources/StickyCore/RailModel.swift`
- Test: `Tests/StickyCoreTests/RailModelTests.swift`

**Interfaces:**
- Consumes: `NoteStore`
- Produces:

```swift
@MainActor public final class RailModel: ObservableObject {
    public let store: NoteStore
    @Published public private(set) var hoveredID: UUID?
    @Published public private(set) var editingID: UUID?
    @Published public private(set) var copiedID: UUID?
    @Published public var draft: String = ""          // 编辑中的文字，视图双向绑定
    @Published public private(set) var isHidden = false
    public var isExpanded: Bool { hoveredID != nil || editingID != nil }

    public init(store: NoteStore, copy: @escaping (String) -> Void)
    public func setHover(_ id: UUID?)          // 编辑中忽略
    public func click(_ id: UUID)              // 编辑中忽略；否则 copy(note.copyText)，copiedID = id
    public func clearCopied(_ id: UUID)        // 仅当 copiedID == id 时清空；1.2 秒定时由视图层调用
    public func beginEdit(_ id: UUID)          // 若正在编辑别的先 commitEdit；editingID = id，draft = note.text
    public func addNote()                      // 先 commitEdit；store.add(text: "")，然后 beginEdit 新便签
    public func commitEdit()                   // 无编辑时空操作；draft 去空白后为空 → 删除该便签，否则 updateText(draft)；editingID = nil，hoveredID = nil
    public func setColor(_ id: UUID, _ c: NoteColor)
    public func delete(_ id: UUID)             // 若正在编辑它，先清 editingID
    public func setHidden(_ hidden: Bool)      // 隐藏前先 commitEdit
}
```

- [ ] **Step 1: 写失败的测试**（`copy` 注入一个把参数追加到数组的闭包；store 用临时目录）

```swift
func testClickCopiesTrimmedText()       // 便签文字 " a \n" → 数组 == ["a"]，copiedID == id
func testClickIgnoredWhileEditing()
func testAddNoteEntersEdit()            // notes 多一张空便签，editingID 是它，draft == ""
func testCommitSavesDraft()             // beginEdit，draft = "新内容"，commitEdit → store 里文字更新，editingID == nil
func testCommitEmptyDeletes()           // addNote 后直接 commitEdit → 便签数量恢复
func testCommitWhitespaceOnlyDeletes()  // draft = " \n " → 删除
func testCommitOnResign()               // beginEdit，draft = "半句话"，setHidden(true) → 文字已保存，isHidden == true
func testBeginEditCommitsPrevious()     // 编辑 A 时 beginEdit(B) → A 的 draft 已保存
func testHoverIgnoredWhileEditing()
func testDeleteWhileEditing()           // editingID 清空，随后 commitEdit 不崩溃
```

- [ ] **Step 2: 运行，确认失败**
- [ ] **Step 3: 实现**
- [ ] **Step 4: 运行 `swift test`，全部 PASS**
- [ ] **Step 5: 提交** `feat: rail interaction model`

---

### Task 5: App 外壳、面板、收起与悬停展开、单击复制、安装脚本

**Files:**
- Create: `Sources/StickySideNote/{AppDelegate,RailPanel,Theme,RailView,NoteView,HoverTracker}.swift`, `Resources/Info.plist`, `Resources/Fonts/DMSans-VariableFont_opsz_wght.ttf`, `scripts/install.sh`
- Modify: `Sources/StickySideNote/main.swift`

**Interfaces:**
- Consumes: `RailModel`, `RailLayout`, `NoteStore.defaultURL`
- Produces:
  - `final class RailPanel: NSPanel`，`canBecomeKey` 返回 `true`，`canBecomeMain` 返回 `false`
  - `@MainActor final class PanelController { init(model: RailModel); func reposition(); func show(); func hide() }`
  - `enum Theme`：`static func color(_ c: NoteColor) -> Color`、`fg`（`#020617`）、`brand`（`#574efa`）、`brandHover`（`#463ee0`）、`brandActive`（`#3a33b8`）、`radiusSm/Md/2xl/3xl`（6/8/16/24）、`shadowSm`、`shadowLg`、`focusRing`、`ease`（`Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.18)`）、`static func font(_ size: CGFloat, _ weight: Font.Weight) -> Font`
  - `struct HoverTracker: NSViewRepresentable`，`init(onChange: @escaping (Bool) -> Void)`

实现决定：

- `main.swift`：`NSApplication.shared`，`setActivationPolicy(.accessory)`，设置 `AppDelegate`，`run()`。
- 面板：`styleMask: [.borderless, .nonactivatingPanel]`，`level = .floating`，`collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`（**不加** `.fullScreenAuxiliary`，这样别的 App 全屏时自然不显示），`isOpaque = false`，`backgroundColor = .clear`，`hasShadow = false`，`hidesOnDeactivate = false`，`becomesKeyOnlyIfNeeded = true`。内容是 `NSHostingView` 的子类，`acceptsFirstMouse(for:)` 返回 `true`。
- 定位（`reposition()`）：屏幕取 `NSScreen.screens.first`，用它的 `visibleFrame`（Dock 在左时自动让开）。`available = visibleFrame.height × 0.87 − 8`。面板左上角在 `(visibleFrame.minX, visibleFrame.maxY − visibleFrame.height × 0.13)`。收起时面板尺寸 = `36 × railHeight`；`model.isExpanded` 时宽度为 `268 + 24`（留出投影），高度为 `available`。左上角始终不动。监听 `model` 的变化和 `NSApplication.didChangeScreenParametersNotification` 调用 `reposition()`。
- 悬停：SwiftUI 的 `.onHover` 在非 key 窗口不可靠，统一用 `HoverTracker`（`NSTrackingArea`，选项 `[.mouseEnteredAndExited, .activeAlways, .inVisibleRect]`）。进入延迟 60 ms、离开延迟 80 ms 再调用 `model.setHover`，期间鼠标进了别的便签则以最新的为准。
- 收起的小条：`36 × layout.tabHeight`，底色 `Theme.color`，`cap` 用 `Theme.font(17, .bold)` 居中，`shadowSm`。形状用 `UnevenRoundedRectangle`：左侧两角 0；奇数位（第 1、3、5 张）右上 20、右下 6，偶数位相反。
- 展开的卡片：宽 268，右侧两角变为 24 / 16（大角位置同上），`shadowLg`；内边距上 12、右 18、下 10、左 16；正文 `Theme.font(14, .regular)`、行距对应 1.5 倍；下方 8 pt 处是提示 `单击复制 · 双击编辑`，`Theme.font(11, .medium)`，颜色为 `fg` 的 64% 透明度。正文区最大高度 = `屏幕可用高度 × 0.6 − 60`，超出时 `ScrollView` 内滚动。卡片的纵向位置用 `layout.cardTop(...)`（卡片实际高度用 `GeometryReader` / `onGeometryChange` 量出）。
- 展开、收起动画统一 `Theme.ease`；宽度和圆角一起过渡，首字淡出、正文淡入。
- 单击：`model.click(id)`；`copy` 闭包里 `NSPasteboard.general.clearContents()` 后 `setString(_, forType: .string)`。`copiedID == id` 时提示改为 `✓ 已复制`，颜色 `fg` 不透明、字重 semibold；1.2 秒后 `model.clearCopied(id)`。
- 字体：启动时用 `CTFontManagerRegisterFontsForURL` 注册 `Bundle.main` 里的 `DMSans-VariableFont_opsz_wght.ttf`；找不到文件时 `Theme.font` 回落 `.system`。字体文件从 `Resources/Fonts/` 复制到 `Resources/Fonts/`；该目录不存在时跳过并在汇报中说明。
- `Info.plist`：`CFBundleIdentifier = com.jimmyli.StickySideNote`，`CFBundleName = StickySideNote`，`CFBundleExecutable = StickySideNote`，`CFBundlePackageType = APPL`，`CFBundleShortVersionString = 0.1.0`，`LSUIElement = true`，`LSMinimumSystemVersion = 14.0`。
- `scripts/install.sh`：`swift build -c release`；在 `.build/StickySideNote.app` 装配 `Contents/MacOS/StickySideNote`、`Contents/Info.plist`、`Contents/Resources/*.ttf`；`codesign --force --sign - `；`pkill -x StickySideNote || true`；替换 `/Applications/StickySideNote.app`；`open` 它。`set -euo pipefail`。

- [ ] **Step 1: 复制字体，写 `Info.plist` 和 `scripts/install.sh`**
- [ ] **Step 2: 实现 `Theme`、`HoverTracker`、`RailPanel` + `PanelController`、`NoteView`（收起 + 展开，不含编辑）、`RailView`（只有便签，暂无 "+"）、`AppDelegate`、`main.swift`**
- [ ] **Step 3: `swift build` 无错误、无警告；`swift test` 仍全部 PASS**
- [ ] **Step 4: 运行 `bash scripts/install.sh`，然后逐项验证并截图（`screencapture -x`）**
  - 左边缘出现示例便签的小条，首字为"悬"，Dock 里没有 StickySideNote 图标。
  - 在 TextEdit 里打字的同时把鼠标移到小条上：卡片滑出、无回弹，TextEdit 仍可继续打字（没有失去焦点）。
  - 单击便签后在 TextEdit 里粘贴，得到全文；提示在约 1.2 秒内显示 `✓ 已复制`。
  - 把一个 Finder 窗口拖到屏幕左边，在便签列右侧 40 pt 处和便签列下方的左边缘处点击、拖动窗口，都正常。
  - 鼠标沿左边缘从上到下快速划过，便签不闪烁。
  - 把 Safari 切到全屏：便签不显示；退出全屏：便签回来。
- [ ] **Step 5: 提交** `feat: floating rail with hover expand and click to copy`

---

### Task 6: 新建与编辑

**Files:**
- Modify: `Sources/StickySideNote/NoteView.swift`, `RailView.swift`, `RailPanel.swift`

**Interfaces:**
- Consumes: `RailModel.addNote / beginEdit / commitEdit / draft / editingID`，`RailLayout.canAdd`

实现决定：

- "+"：`28 × 32`，底色 `Theme.brand`，白色 "+"（`Theme.font(18, .medium)`），右侧两角 8；悬停 `brandHover`、按下 `brandActive`，不缩放。`layout.canAdd` 为 false 时不显示。点击 `model.addNote()`。
- 双击便签 → `model.beginEdit(id)`。用 `.onTapGesture(count: 2)` 与单击并存，且单击必须零延迟：单击手势用 `simultaneousGesture`，不要让系统等双击超时。
- 编辑态：卡片保持展开；正文换成绑定 `model.draft` 的 `TextEditor`（纯文本、多行，`scrollContentBackground(.hidden)`，字体同正文），自动获得焦点；描边 2 pt `Theme.brand` 加 `focusRing`（4 pt、`#574efa` 20% 透明度）；提示改为 `Esc 或点别处保存`。
- `editingID` 变为非 nil 时 `PanelController` 调用 `panel.makeKey()`（不调用 `NSApp.activate`）；变回 nil 时 `panel.resignKey()` 并把 key 交还（`orderFrontRegardless` 保持显示即可）。
- 结束编辑：`.onKeyPress(.escape)` → `model.commitEdit()`；面板的 `windowDidResignKey` → `model.commitEdit()`；点击面板内其他便签或 "+" 由模型处理。

- [ ] **Step 1: 实现**
- [ ] **Step 2: `swift build` 无警告；`swift test` 全部 PASS**
- [ ] **Step 3: `bash scripts/install.sh` 后验证并截图**
  - 点 "+"：列尾出现展开的空便签（颜色 cyan），可直接打字；输入"测试 一二三"后按 Esc，小条首字为"测"。
  - 双击这张便签，追加一行（回车换行），点 TextEdit 窗口：内容已保存，TextEdit 成为前台。
  - 从网页复制一段带格式的文字粘贴进去：只有纯文本。
  - 点 "+" 后什么都不输直接按 Esc：便签消失。
  - 连续新建直到放满：最后 "+" 消失。
  - 退出 App（`pkill -x StickySideNote`）再 `open /Applications/StickySideNote.app`：便签内容、颜色、顺序不变。
- [ ] **Step 4: 提交** `feat: create and edit notes in place`

---

### Task 7: 右键菜单

**Files:**
- Create: `Sources/StickySideNote/NoteMenu.swift`
- Modify: `Sources/StickySideNote/NoteView.swift`

**Interfaces:**
- Consumes: `RailModel.setColor / delete`
- Produces: `@MainActor enum NoteMenu { static func show(for note: Note, model: RailModel, in view: NSView, at point: NSPoint) }`

实现决定：

- 用系统 `NSMenu`（`popUp(positioning:at:in:)`），不自绘卡片。第一项是自定义 `view`：一行六个 18 pt 的圆点，间距 8，颜色按 sky → sun 顺序，当前颜色外加 2 pt `Theme.brand` 圆环；点一下 `model.setColor` 并关闭菜单。分隔线。最后一项 `删除便签` → `model.delete`，不弹确认。
- 触发：便签上的次要点击（右键或 Control-单击），通过 `HoverTracker` 所在的 NSView 重写 `rightMouseDown` / `menu(for:)` 取得事件，不要用 SwiftUI `.contextMenu`（它在不激活的面板里不可靠）。
- 菜单打开期间便签保持展开；关闭后按鼠标位置恢复悬停状态。

- [ ] **Step 1: 实现**
- [ ] **Step 2: `swift build` 无警告；`swift test` 全部 PASS**
- [ ] **Step 3: `bash scripts/install.sh` 后验证并截图**：右键便签出现六个圆点和 `删除便签`；点 gold 圆点便签变色；重启后颜色还在；`删除便签` 后便签消失、下面的便签上移。
- [ ] **Step 4: 提交** `feat: context menu for colour and delete`

---

### Task 8: 菜单栏、隐藏/显示、开机自启动、屏幕变化

**Files:**
- Modify: `Sources/StickySideNote/AppDelegate.swift`, `RailPanel.swift`

**Interfaces:**
- Consumes: `RailModel.addNote / setHidden / isHidden / commitEdit`，`RailLayout.canAdd`，`PanelController.show / hide / reposition`

实现决定：

- `NSStatusItem`（`squareLength`），图标用 SF Symbol `note.text`（模板图）。菜单项依次：`新建便签`（`canAdd` 为 false 时置灰）、`隐藏全部便签` / `显示全部便签`（随 `isHidden` 切换标题）、分隔线、`开机自动启动`（勾选状态 = `SMAppService.mainApp.status == .enabled`，点击时 `register()` / `unregister()`，失败 `NSLog`）、分隔线、`退出`。
- `新建便签` 在隐藏状态下先 `setHidden(false)`。
- 首次启动默认开启自启动：`UserDefaults` 键 `didApplyLoginDefault` 为 false 且 `Bundle.main.bundlePath` 以 `/Applications/` 开头时，`register()` 一次并置为 true。从别处运行（如 `swift run`）不注册。
- `applicationWillTerminate` 调用 `model.commitEdit()`。
- `didChangeScreenParametersNotification` 和 `NSWorkspace.activeSpaceDidChangeNotification` 触发 `reposition()`。

- [ ] **Step 1: 实现**
- [ ] **Step 2: `swift build` 无警告；`swift test` 全部 PASS**
- [ ] **Step 3: `bash scripts/install.sh` 后验证并截图**
  - 菜单栏出现图标，五个菜单项文案正确；`隐藏全部便签` 后便签列消失、标题变为 `显示全部便签`，再点恢复。
  - 双击一张便签输入"半句话"，不按 Esc，直接从菜单栏点 `退出`；重新打开，"半句话"已保存。
  - 同样在编辑中点 `隐藏全部便签` 再显示：文字已保存。
  - `开机自动启动` 已勾选；`sfltool dumpbtm | grep -i StickySideNote` 能看到条目。取消勾选后条目状态变为 disabled 或消失。
  - 在"系统设置 → 桌面与程序坞"把 Dock 移到左边：便签列移到 Dock 右侧；移回底部：便签回到左边缘。
  - 在"系统设置 → 显示器"切换到更大的缩放（可用高度变小）：全部便签仍然可见，必要时小条变矮。
- [ ] **Step 4: 提交** `feat: menu bar, hide and show, launch at login`

---

### Task 9: 按 spec 第 8 节整体验收

**Files:**
- Create: `README.md`（安装：`bash scripts/install.sh`；卸载：退出 App、取消开机自启动、删除 `/Applications/StickySideNote.app` 和 `~/Library/Application Support/StickySideNote/`；手势说明四行）

- [ ] **Step 1: 全新安装验收**：`pkill -x StickySideNote`，把 `~/Library/Application Support/StickySideNote/` 改名备份，`bash scripts/install.sh`，按 spec 第 8 节 1–7 条逐条走一遍，每条截图，记录通过或失败。
- [ ] **Step 2: 与原型对照**：浏览器打开 `docs/superpowers/specs/prototype.html`，并排比较收起形状、展开尺寸、颜色、提示文字、动画；列出差异并修正（系统菜单替代自绘菜单卡片是已知差异，不算）。
- [ ] **Step 3: 损坏文件演练**：退出 App，往 `notes.json` 写入 `{bad`，启动：App 正常、便签列为空只有 "+"，目录里有 `notes.corrupt-*.json`。恢复第 1 步备份的数据。
- [ ] **Step 4: `swift test` 全部 PASS，`swift build -c release` 无警告**
- [ ] **Step 5: 提交** `docs: README and acceptance pass`
