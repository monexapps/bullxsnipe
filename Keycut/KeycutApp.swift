import SwiftUI
import AppKit
import Cocoa

// MARK: - Main Application Definition
@main
struct KeycutApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    
    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 10) {
                Text(clipboardManager.isMonitoring ? "Status: Monitoring Clipboard" : "Status: Paused")
                    .font(.headline)
                
                Text("Last copied: \(clipboardManager.lastCopiedContent)")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 250)
                
                Divider()
                
                Button(clipboardManager.isMonitoring ? "Pause Monitoring" : "Resume Monitoring") {
                    clipboardManager.toggleMonitoring()
                }
                
                Button("Test Telegram Action") {
                    clipboardManager.executeTelegramAction()
                }
                
                Button("Test Direct Paste") {
                    clipboardManager.testDirectPaste()
                }
                .foregroundColor(.orange)
                
                Button("Check Permissions") {
                    clipboardManager.checkAllPermissions()
                }
                .foregroundColor(.blue)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        } label: {
            Image(systemName: clipboardManager.isMonitoring ? "doc.on.clipboard.fill" : "doc.on.clipboard")
        }
    }
}

// MARK: - Clipboard Manager
class ClipboardManager: ObservableObject {
    private let telegramUsername = "" // Without '@'
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    
    @Published var lastCopiedContent: String = "Nothing yet."
    @Published var isMonitoring: Bool = true
    
    init() {
        print("🚀 Initializing ClipboardManager...")
        self.lastChangeCount = NSPasteboard.general.changeCount
        checkAllPermissions()
        startMonitoring()
    }
    
    func checkAllPermissions() {
        // Check Accessibility permissions
        let accessEnabled = AXIsProcessTrusted()
        print(accessEnabled ? "✅ Accessibility permissions granted." : "🚫 Accessibility permissions not granted.")
        
        if !accessEnabled {
            print("Please enable Accessibility permissions in System Settings > Privacy & Security > Accessibility")
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
        }
    }
    
    func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            startMonitoring()
            print("▶️ Clipboard monitoring resumed.")
        } else {
            stopMonitoring()
            print("⏸️ Clipboard monitoring paused.")
        }
    }
    
    private func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        print("⏰ Clipboard monitoring started.")
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        print("🛑 Clipboard monitoring stopped.")
    }
    
    private func checkClipboard() {
        guard isMonitoring else { return }
        
        let pasteboard = NSPasteboard.general
        
        if pasteboard.changeCount != lastChangeCount {
            print("✅ Clipboard change detected!")
            lastChangeCount = pasteboard.changeCount
            
            if let copiedString = pasteboard.string(forType: .string) {
                let trimmedString = copiedString.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    self.lastCopiedContent = trimmedString.isEmpty ? "Empty string copied." : trimmedString
                    print("📋 Clipboard content: '\(self.lastCopiedContent.prefix(50))...'")
                }
                executeTelegramAction()
            } else {
                DispatchQueue.main.async {
                    self.lastCopiedContent = "Non-text content copied."
                }
            }
        }
    }
    
    public func executeTelegramAction() {
        guard let url = URL(string: "tg://resolve?domain=\(telegramUsername)") else {
            print("🚫 Error: Invalid Telegram URL for username '\(telegramUsername)'.")
            return
        }
        
        print("🌐 Opening Telegram URL: \(url)")
        let success = NSWorkspace.shared.open(url)
        print(success ? "✅ Successfully opened Telegram URL." : "🚫 Failed to open Telegram URL.")
        
        // Wait longer for Telegram to fully load and focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.ensureTelegramFocusAndPaste()
        }
    }
    
    func testDirectPaste() {
        print("🧪 Testing direct paste method...")
        pasteAndSendDirect()
    }
    
    private func ensureTelegramFocusAndPaste() {
        // Check if Telegram is the frontmost app
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("🚫 No frontmost application detected")
            return
        }
        
        print("ℹ️ Current frontmost app: \(frontmostApp.localizedName ?? "Unknown")")
        
        if frontmostApp.bundleIdentifier != "ru.keepcoder.Telegram" {
            print("⚠️ Telegram is not frontmost, attempting to activate...")
            activateTelegram()
            
            // Wait a bit more and try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.pasteAndSendDirect()
            }
        } else {
            print("✅ Telegram is frontmost, proceeding with paste...")
            pasteAndSendDirect()
        }
    }
    
    private func activateTelegram() {
        // Try to activate Telegram using NSRunningApplication
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "ru.keepcoder.Telegram")
        
        if let telegramApp = runningApps.first {
            print("📱 Activating Telegram app...")
            telegramApp.activate(options: [.activateIgnoringOtherApps])
        } else {
            print("⚠️ Telegram app not found in running applications")
        }
    }
    
    private func pasteAndSendDirect() {
        // Check if accessibility is enabled
        guard AXIsProcessTrusted() else {
            print("🚫 Accessibility permissions required for direct paste")
            checkAllPermissions()
            return
        }
        
        print("⌨️ Sending direct keyboard events...")
        
        // First, press Tab to focus the message input field
        print("⇥ Pressing Tab to focus message input...")
        sendKeyboardEvent(keyCode: 48, flags: []) // Tab key
        usleep(300000) // 0.3 seconds wait
        
        // Send Cmd+V (paste)
        print("📋 Pasting with Cmd+V...")
        sendKeyboardEvent(keyCode: 9, flags: .maskCommand) // 'V' key with Cmd
        
        // Wait for paste to complete
        usleep(500000) // 0.5 seconds
        
        // Send Return key
        print("↵ Sending Return key...")
        sendKeyboardEvent(keyCode: 36, flags: []) // Return key
        
        print("✅ Direct keyboard events sent")
    }
    
    private func sendKeyboardEvent(keyCode: CGKeyCode, flags: CGEventFlags) {
        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            print("🚫 Failed to create key down event")
            return
        }
        
        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("🚫 Failed to create key up event")
            return
        }
        
        // Set flags (like Cmd key)
        keyDownEvent.flags = flags
        keyUpEvent.flags = flags
        
        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)
        usleep(50000) // Small delay between key down and up
        keyUpEvent.post(tap: .cghidEventTap)
        
        print("⌨️ Posted key event: \(keyCode) with flags: \(flags)")
    }
}
