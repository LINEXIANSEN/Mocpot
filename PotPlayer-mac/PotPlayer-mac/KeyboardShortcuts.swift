import SwiftUI

struct KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()

    struct Shortcut {
        let key: String
        let modifiers: NSEvent.ModifierFlags
        let action: String
    }

    let shortcuts: [Shortcut] = [
        Shortcut(key: "Space", modifiers: [], action: "播放/暂停"),
        Shortcut(key: "Return", modifiers: [], action: "播放/暂停"),
        Shortcut(key: "Escape", modifiers: [], action: "停止/退出全屏"),
        Shortcut(key: "←", modifiers: [], action: "快退 10 秒"),
        Shortcut(key: "→", modifiers: [], action: "快进 10 秒"),
        Shortcut(key: "↑", modifiers: [.command], action: "增大音量"),
        Shortcut(key: "↓", modifiers: [.command], action: "减小音量"),
        Shortcut(key: "M", modifiers: [], action: "静音切换"),
        Shortcut(key: "F", modifiers: [], action: "全屏切换"),
        Shortcut(key: "O", modifiers: [.command], action: "打开文件"),
        Shortcut(key: "L", modifiers: [.command], action: "切换播放列表"),
        Shortcut(key: "I", modifiers: [.command], action: "显示信息"),
        Shortcut(key: "[", modifiers: [.command], action: "上一个"),
        Shortcut(key: "]", modifiers: [.command], action: "下一个"),
        Shortcut(key: "R", modifiers: [.command], action: "循环播放"),
        Shortcut(key: "D", modifiers: [.command], action: "3D 模式"),
        Shortcut(key: "V", modifiers: [.command], action: "VR 模式"),
        Shortcut(key: "W", modifiers: [.command], action: "关闭"),
        Shortcut(key: "Q", modifiers: [.command], action: "退出"),
        Shortcut(key: ",", modifiers: [.command], action: "偏好设置"),
    ]

    func getShortcutDisplay(_ shortcut: Shortcut) -> String {
        var display = ""
        if shortcut.modifiers.contains(.command) { display += "⌘" }
        if shortcut.modifiers.contains(.option) { display += "⌥" }
        if shortcut.modifiers.contains(.control) { display += "⌃" }
        if shortcut.modifiers.contains(.shift) { display += "⇧" }
        display += shortcut.key
        return display
    }
}

struct ShortcutsView: View {
    let manager = KeyboardShortcutManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷键")
                .font(.title2)
                .fontWeight(.bold)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(manager.shortcuts, id: \.action) { shortcut in
                        HStack {
                            Text(manager.getShortcutDisplay(shortcut))
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 120, alignment: .leading)

                            Text(shortcut.action)
                                .font(.body)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 400, height: 500)
    }
}
