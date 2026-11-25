import Testing
@testable import SnipLite

/// The notes as releases have them: both languages in one body, each with other sections after.
private let body = """
## English

### What's new

- The first entry.
- The second one
  goes on here.

### Install

- not this

## 中文

### 更新内容

- 第一条。
* 第二条。

### 安装

- 这条不要
"""

@Test func notesAreTheEntriesOfTheirLanguage() {
    #expect(Updater.notes(in: body, chinese: false) == ["The first entry.", "The second one goes on here."])
    #expect(Updater.notes(in: body, chinese: true) == ["第一条。", "第二条。"])
}

@Test func notesWithWindowsLineEnds() {
    #expect(Updater.notes(in: "### What's new\r\n\r\n- a\r\n- b\r\n", chinese: false) == ["a", "b"])
}

@Test func noNotesWithoutTheHeading() {
    #expect(Updater.notes(in: "", chinese: false).isEmpty)
    #expect(Updater.notes(in: "- a list\n### Other\n- b", chinese: true).isEmpty)
}

@MainActor @Test func versionsCompareByTheirNumbers() {
    #expect(Updater.newer("1.0.12", than: "1.0.11"))
    #expect(Updater.newer("1.0.10", than: "1.0.9"))
    #expect(Updater.newer("1.1", than: "1.0.99"))
    #expect(!Updater.newer("1.0.11", than: "1.0.11"))
    #expect(!Updater.newer("1.0", than: "1.0.0"))
    #expect(!Updater.newer("1.0.9", than: "1.0.10"))
}
