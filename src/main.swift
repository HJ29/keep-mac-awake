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

    /// The app icon's moon as a menu bar template, alpha carrying its tones: gibbous when awake, a thin crescent when not.
    private static func moonImage(awake: Bool, description: String) -> NSImage {
        let craters: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.35, 0.30, 0.20), (-0.10, -0.40, 0.19), (0.15, 0.48, 0.12), (-0.45, -0.22, 0.13),
            (-0.80, -0.48, 0.14), (0.75, 0.25, 0.10), (0.68, -0.40, 0.07), (0.50, 0.62, 0.11),
        ]
        let litFraction: CGFloat = awake ? 0.78 : 0.22
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let r: CGFloat = 8, a = r * abs(litFraction - 0.5) * 2
            let c = NSPoint(x: rect.midX, y: rect.midY)
            let moon = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            let ellipse = NSBezierPath(ovalIn: NSRect(x: c.x - a, y: c.y - r, width: 2 * a, height: 2 * r))
            let leftHalf = NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY, width: c.x - rect.minX, height: rect.height))
            // Fills the clipped area with a surface alpha, then the craters; .copy replaces alpha instead of stacking.
            func paint(_ surface: CGFloat, _ crater: CGFloat) {
                NSGraphicsContext.current?.compositingOperation = .copy
                NSColor(white: 0, alpha: surface).setFill()
                rect.fill(using: .copy)
                NSColor(white: 0, alpha: crater).setFill()
                for (x, y, cr) in craters {
                    NSBezierPath(ovalIn: NSRect(x: c.x + (x - cr) * r, y: c.y + (y - cr) * r, width: 2 * cr * r, height: 2 * cr * r)).fill()
                }
            }
            NSGraphicsContext.saveGraphicsState()
            moon.addClip()
            paint(0.30, 0.18)
            NSGraphicsContext.restoreGraphicsState()

            // Lit side: the left half plus the ellipse (gibbous) or minus it (crescent).
            NSGraphicsContext.saveGraphicsState()
            moon.addClip()
            if litFraction >= 0.5 {
                let lit = NSBezierPath()
                lit.append(leftHalf)
                lit.append(ellipse)
                lit.addClip()
            } else {
                leftHalf.addClip()
                let lit = NSBezierPath(rect: rect)
                lit.append(ellipse)
                lit.windingRule = .evenOdd
                lit.addClip()
            }
            paint(1.0, 0.55)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = description
        return image
    }

    private static let awakeImage = moonImage(awake: true, description: "Mac awake")
    private static let normalImage = moonImage(awake: false, description: "Normal sleep")

    private func refresh() {
        let on = sleepDisabled
        // Filled vs outline of the same glyph is the standard macOS on/off read.
        statusItem.button?.image = on ? Controller.awakeImage : Controller.normalImage
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
