import AppKit
import IOKit
import IOKit.pwr_mgt

/// Menu-bar app: Keep Mac Awake (`pmset -a disablesleep`, lid closed too) and Keep Screen Awake (display assertion).
final class Controller: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "Keep Mac Awake", action: nil, keyEquivalent: "")
    private let displayItem = NSMenuItem(title: "Keep Screen Awake", action: nil, keyEquivalent: "")
    /// Dies with this process, so quitting always hands display sleep (and auto-lock) back to the system.
    private var displayAssertion = IOPMAssertionID(kIOPMNullAssertionID)
    private var timer: Timer?

    override init() {
        super.init()

        let menu = NSMenu()
        menu.delegate = self

        toggleItem.target = self
        toggleItem.action = #selector(toggle)
        menu.addItem(toggleItem)

        displayItem.target = self
        displayItem.action = #selector(toggleDisplay)
        menu.addItem(displayItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    private func run(_ path: String, _ args: [String]) -> (code: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do { try task.run() } catch { return (-1, "failed to launch \(path): \(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    /// Read straight from the IORegistry so the poll never forks a process. Absent key means off.
    private var sleepDisabled: Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(service) }
        let property = IORegistryEntryCreateCFProperty(service, "SleepDisabled" as CFString, kCFAllocatorDefault, 0)
        return (property?.takeRetainedValue() as? Bool) ?? false
    }

    private func refresh() {
        let on = sleepDisabled
        let description = on ? "Mac awake" : "Normal sleep"
        // Filled vs outline of the same glyph is the standard macOS on/off read.
        let symbol = on ? "cup.and.saucer.fill" : "cup.and.saucer"

        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description) {
            image.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.title = ""
        } else {
            statusItem.button?.title = on ? "☕" : "z"
        }
        let displayOn = displayAssertion != kIOPMNullAssertionID
        statusItem.button?.toolTip = (on
            ? "Mac stays awake, even with the lid closed"
            : "Mac sleeps normally")
            + (displayOn ? "; screen stays awake" : "")
        toggleItem.state = on ? .on : .off
        displayItem.state = displayOn ? .on : .off
    }

    @objc private func toggle() {
        let target = sleepDisabled ? "0" : "1"
        let result = run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", target])
        if result.code != 0 {
            showFailure("Couldn't change the sleep setting", """
                `sudo -n` was refused, so the sudoers rule is missing or no longer matches. Run ./install.sh again.

                \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
                """)
        }
        refresh()
    }

    @objc private func toggleDisplay() {
        if displayAssertion != kIOPMNullAssertionID {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = IOPMAssertionID(kIOPMNullAssertionID)
        } else {
            // Literal because kIOPMAssertPreventUserIdleDisplaySleep is a CFSTR macro Swift can't import.
            let result = IOPMAssertionCreateWithName("PreventUserIdleDisplaySleep" as CFString,
                                                     IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                     "Keep Mac Awake (Keep Screen Awake)" as CFString,
                                                     &displayAssertion)
            if result != kIOReturnSuccess {
                displayAssertion = IOPMAssertionID(kIOPMNullAssertionID)
                showFailure("Couldn't keep the screen awake", "IOPMAssertionCreateWithName returned \(result).")
            }
        }
        refresh()
    }

    private func showFailure(_ message: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller()
app.run()
