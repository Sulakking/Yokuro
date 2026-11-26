// Substitut d'AppKit : uniquement les API utilisées par Yokuro, avec leurs vraies signatures.
@_exported import Foundation
@_exported import Dispatch

public struct Selector: ExpressibleByStringLiteral {
    public init(_ name: String) {}
    public init(stringLiteral value: String) {}
}

// Propres à Darwin
public let O_EVTONLY: Int32 = 0x8000
public protocol DispatchSourceFileSystemObject: AnyObject {
    func setEventHandler(handler: (() -> Void)?)
    func setCancelHandler(handler: (() -> Void)?)
    func resume()
}
extension DispatchSource {
    public class func makeFileSystemObjectSource(fileDescriptor: Int32, eventMask: FileSystemEvent,
                                                 queue: DispatchQueue? = nil) -> DispatchSourceFileSystemObject {
        fatalError()
    }
}
extension ProcessInfo {
    public struct ActivityOptions: OptionSet {
        public let rawValue: UInt64
        public init(rawValue: UInt64) { self.rawValue = rawValue }
        public static let userInitiated = ActivityOptions(rawValue: 1)
        public static let userInitiatedAllowingIdleSystemSleep = ActivityOptions(rawValue: 2)
        public static let background = ActivityOptions(rawValue: 4)
    }
    public func beginActivity(options: ActivityOptions, reason: String) -> NSObjectProtocol { NSObject() }
}
extension FileManager {
    public func trashItem(at url: URL, resultingItemURL outResultingURL: UnsafeMutablePointer<NSURL?>?) throws {}
}
extension NSString {
    public var abbreviatingWithTildeInPath: String { self as String }
}

// MARK: Application

public var NSApp: NSApplication! { NSApplication.shared }

public protocol NSApplicationDelegate: AnyObject {
    func applicationDidFinishLaunching(_ notification: Notification)
}
extension NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {}
}

open class NSResponder: NSObject {}

open class NSApplication: NSResponder {
    public static let shared = NSApplication()
    public enum ActivationPolicy { case regular, accessory, prohibited }
    public struct ModalResponse: Equatable {
        public static let OK = ModalResponse()
        public static let cancel = ModalResponse()
    }
    public weak var delegate: NSApplicationDelegate?
    public var mainMenu: NSMenu?
    @discardableResult public func setActivationPolicy(_ policy: ActivationPolicy) -> Bool { true }
    public func run() {}
    public func activate(ignoringOtherApps flag: Bool) {}
    public func terminate(_ sender: Any?) {}
}

open class NSRunningApplication: NSObject {
    public class func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [NSRunningApplication] { [] }
}

open class NSWorkspace: NSObject {
    public static let shared = NSWorkspace()
    public struct IconCreationOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
    }
    @discardableResult public func setIcon(_ image: NSImage?, forFile fullPath: String, options: IconCreationOptions = []) -> Bool { true }
    public var fileLabels: [String] { [] }
    @discardableResult public func open(_ url: URL) -> Bool { true }
}

// MARK: Vues

open class NSView: NSResponder {
    public init(frame frameRect: NSRect) {}
    public override convenience init() { self.init(frame: .zero) }
    public var window: NSWindow? { nil }
    public var bounds: NSRect { .zero }
    public var translatesAutoresizingMaskIntoConstraints = true
    public func addSubview(_ view: NSView) {}
    public var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
    public var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
}

open class NSLayoutConstraint: NSObject {
    public class func activate(_ constraints: [NSLayoutConstraint]) {}
}
open class NSLayoutAnchor<AnchorType: AnyObject>: NSObject {
    public func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint { NSLayoutConstraint() }
}
open class NSLayoutXAxisAnchor: NSLayoutAnchor<NSLayoutXAxisAnchor> {}
open class NSLayoutYAxisAnchor: NSLayoutAnchor<NSLayoutYAxisAnchor> {}

open class NSControl: NSView {
    public enum ImagePosition { case noImage, imageOnly, imageLeft, imageRight, imageBelow, imageAbove, imageOverlaps, imageLeading, imageTrailing }
    public weak var target: AnyObject?
    public var action: Selector?
}
open class NSButton: NSControl {
    public var title = ""
    public var image: NSImage?
    public var imagePosition: NSControl.ImagePosition = .noImage
}
open class NSStatusBarButton: NSButton {}

open class NSPopUpButton: NSButton {
    public init(frame buttonFrame: NSRect, pullsDown flag: Bool) { super.init(frame: buttonFrame) }
    public func addItem(withTitle title: String) {}
    public func addItems(withTitles itemTitles: [String]) {}
    public func selectItem(at index: Int) {}
    public var indexOfSelectedItem: Int { 0 }
}

open class NSTextField: NSControl {
    public convenience init(labelWithString stringValue: String) { self.init(frame: .zero) }
}

open class NSGridCell: NSObject {
    public enum Placement { case inherited, none, leading, top, trailing, bottom, center, fill }
}
open class NSGridColumn: NSObject {
    public var xPlacement: NSGridCell.Placement = .inherited
}
open class NSGridView: NSView {
    public convenience init(views rows: [[NSView]]) { self.init(frame: .zero) }
    public func column(at index: Int) -> NSGridColumn { NSGridColumn() }
    public var rowSpacing: CGFloat = 0
    public var columnSpacing: CGFloat = 0
}

public enum NSCompositingOperation { case copy, sourceOver, destinationIn, color }
open class NSColorSpace: NSObject {
    public static let sRGB = NSColorSpace()
}
open class NSColor: NSObject {
    public init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
    public func setFill() {}
    public func usingColorSpace(_ space: NSColorSpace) -> NSColor? { self }
    public var redComponent: CGFloat { 0 }
    public var greenComponent: CGFloat { 0 }
    public var blueComponent: CGFloat { 0 }
}
extension CGRect {
    public func fill(using operation: NSCompositingOperation) {}
}
open class NSImage: NSObject {
    public typealias Name = String
    public static let folderName: Name = "NSFolder"
    public init?(named name: Name) {}
    public init(size: NSSize) {}
    public func lockFocus() {}
    public func unlockFocus() {}
    public func draw(in rect: NSRect) {}
    public func draw(in rect: NSRect, from fromRect: NSRect, operation op: NSCompositingOperation, fraction delta: CGFloat) {}
    public init?(systemSymbolName symbolName: String, accessibilityDescription description: String?) {}
    public init?(contentsOf url: URL) {}
    public var size: NSSize = .zero
    public var isTemplate = false
}

// MARK: Barre de menus

open class NSStatusBar: NSObject {
    public static let system = NSStatusBar()
    public func statusItem(withLength length: CGFloat) -> NSStatusItem { NSStatusItem() }
}
open class NSStatusItem: NSObject {
    public static let variableLength: CGFloat = -1
    public static let squareLength: CGFloat = -2
    public var button: NSStatusBarButton? { nil }
    public var menu: NSMenu?
}
open class NSMenuItem: NSObject {
    public override init() {}
    public var submenu: NSMenu?
}
open class NSMenu: NSObject {
    public init(title: String) {}
    public override convenience init() { self.init(title: "") }
    public func addItem(_ newItem: NSMenuItem) {}
    @discardableResult public func addItem(withTitle string: String, action selector: Selector?,
                                           keyEquivalent charCode: String) -> NSMenuItem { NSMenuItem() }
}

// MARK: Fenêtres

open class NSViewController: NSResponder {
    public var view: NSView { NSView() }
}

open class NSWindow: NSResponder {
    public struct StyleMask: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let titled = StyleMask(rawValue: 1)
        public static let closable = StyleMask(rawValue: 2)
        public static let resizable = StyleMask(rawValue: 8)
    }
    public enum BackingStoreType { case retained, nonretained, buffered }
    public init(contentRect: NSRect, styleMask style: StyleMask, backing backingStoreType: BackingStoreType,
                defer flag: Bool) {}
    public var title = ""
    public var isReleasedWhenClosed = true
    public var contentViewController: NSViewController?
    public var isVisible: Bool { false }
    public func setContentSize(_ size: NSSize) {}
    public func center() {}
    public func makeKey() {}
    public func makeKeyAndOrderFront(_ sender: Any?) {}
    public func close() {}
}

open class NSOpenPanel: NSWindow {
    public init() { super.init(contentRect: .zero, styleMask: [], backing: .buffered, defer: false) }
    public var canChooseDirectories = false
    public var canChooseFiles = true
    public var allowsMultipleSelection = false
    public var directoryURL: URL?
    public var message: String!
    public var prompt: String!
    public var accessoryView: NSView?
    public var isAccessoryViewDisclosed = false
    public var url: URL? { nil }
    public func runModal() -> NSApplication.ModalResponse { .OK }
}

open class NSAlert: NSObject {
    public override init() {}
    public var messageText = ""
    public var informativeText = ""
    @discardableResult public func runModal() -> NSApplication.ModalResponse { .OK }
}

public protocol NSPopoverDelegate: AnyObject {
    func popoverDidClose(_ notification: Notification)
}
extension NSPopoverDelegate {
    public func popoverDidClose(_ notification: Notification) {}
}
open class NSPopover: NSResponder {
    public enum Behavior { case applicationDefined, transient, semitransient }
    public override init() {}
    public var behavior: Behavior = .applicationDefined
    public weak var delegate: NSPopoverDelegate?
    public var contentViewController: NSViewController?
    public var isShown: Bool { false }
    public func performClose(_ sender: Any?) {}
    public func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {}
}
