// Substitut de SwiftUI pour vérifier les types sous Linux.
// Uniquement les API utilisées par Yokuro, déclarées avec leurs signatures réelles.
@_exported import Combine
@_exported import Foundation
import AppKit

// MARK: View et ViewBuilder

public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

extension Never: View {
    public var body: Never { fatalError() }
}

public protocol _PrimitiveView: View where Body == Never {}
extension _PrimitiveView {
    public var body: Never { fatalError() }
}

extension Optional: View where Wrapped: View {
    public var body: Never { fatalError() }
}

public struct EmptyView: _PrimitiveView { public init() {} }
public struct TupleView<T>: _PrimitiveView { public init(_ value: T) {} }
public struct _ConditionalContent<TrueContent: View, FalseContent: View>: _PrimitiveView {}
public struct ModifiedContent<Content: View>: _PrimitiveView {}

public struct AnyView: _PrimitiveView {
    public init<V: View>(_ view: V) {}
}

@resultBuilder
public struct ViewBuilder {
    public static func buildExpression<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<(repeat each Content)> {
        TupleView((repeat each content))
    }
    public static func buildIf<Content: View>(_ content: Content?) -> Content? { content }
    public static func buildEither<T: View, F: View>(first: T) -> _ConditionalContent<T, F> { _ConditionalContent() }
    public static func buildEither<T: View, F: View>(second: F) -> _ConditionalContent<T, F> { _ConditionalContent() }
}

// MARK: Texte localisé

public protocol _FormatSpecifiable {}
extension Int: _FormatSpecifiable {}
extension Double: _FormatSpecifiable {}
extension UInt64: _FormatSpecifiable {}

public struct LocalizedStringKey: ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {}
    public init(stringInterpolation: StringInterpolation) {}
    public struct StringInterpolation: StringInterpolationProtocol {
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) {}
        public mutating func appendInterpolation(_ string: String) {}
        public mutating func appendInterpolation<T: _FormatSpecifiable>(_ value: T) {}
        public mutating func appendInterpolation(_ text: Text) {}
    }
}

// MARK: Styles

public protocol ShapeStyle {}
public struct Color: ShapeStyle, _PrimitiveView, Hashable {
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {}
    init() {}
    public static let primary = Color()
    public static let black = Color()
    public static let clear = Color()
    public static let white = Color()
    public static let red = Color()
    public static let accentColor = Color()
    public func opacity(_ opacity: Double) -> Color { self }
}
public struct HierarchicalShapeStyle: ShapeStyle {}
public struct Material: ShapeStyle {}
extension ShapeStyle where Self == Color {
    public static var white: Color { Color() }
    public static var red: Color { Color() }
}
extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var secondary: HierarchicalShapeStyle { HierarchicalShapeStyle() }
}
extension ShapeStyle where Self == Material {
    public static var ultraThinMaterial: Material { Material() }
}

public struct Font {
    public enum Weight { case regular, medium, semibold, bold }
    public enum Design { case `default`, serif, rounded, monospaced }
    public static func system(size: CGFloat, weight: Weight = .regular, design: Design = .default) -> Font { Font() }
}

public struct FillStyle { public init() {} }
public enum RoundedCornerStyle { case circular, continuous }
public protocol Shape: View {}
public protocol InsettableShape: Shape {}
extension InsettableShape {
    public func strokeBorder<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> some View {
        EmptyView()
    }
}
public struct Rectangle: InsettableShape, _PrimitiveView { public init() {} }
public struct Circle: InsettableShape, _PrimitiveView { public init() {} }
extension Shape {
    public func fill<S: ShapeStyle>(_ content: S, style: FillStyle = FillStyle()) -> some View { EmptyView() }
}
public struct ColorPicker<Label: View>: _PrimitiveView {}
extension ColorPicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Color>, supportsOpacity: Bool = true) {}
}
public struct RoundedRectangle: InsettableShape, _PrimitiveView {
    public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) {}
}

public struct Alignment { public static let center = Alignment(); public static let leading = Alignment() }

public enum ColorScheme { case light, dark }
public struct EnvironmentValues {
    public var colorScheme: ColorScheme { .light }
}
@propertyWrapper
public struct Environment<Value> {
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {}
    public var wrappedValue: Value { fatalError() }
}
public struct HorizontalAlignment {
    public static let leading = HorizontalAlignment()
    public static let center = HorizontalAlignment()
    public static let trailing = HorizontalAlignment()
}
public struct VerticalAlignment {
    public static let top = VerticalAlignment()
    public static let center = VerticalAlignment()
    public static let bottom = VerticalAlignment()
}
public enum Edge {
    public struct Set: OptionSet {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1)
        public static let leading = Set(rawValue: 2)
        public static let bottom = Set(rawValue: 4)
        public static let trailing = Set(rawValue: 8)
        public static let all: Set = [.top, .leading, .bottom, .trailing]
        public static let horizontal: Set = [.leading, .trailing]
        public static let vertical: Set = [.top, .bottom]
    }
}
public enum Axis {
    public struct Set: OptionSet {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1)
        public static let vertical = Set(rawValue: 2)
    }
}

public protocol PrimitiveButtonStyle {}
public struct PlainButtonStyle: PrimitiveButtonStyle {}
public struct BorderlessButtonStyle: PrimitiveButtonStyle {}
extension PrimitiveButtonStyle where Self == PlainButtonStyle { public static var plain: PlainButtonStyle { PlainButtonStyle() } }
extension PrimitiveButtonStyle where Self == BorderlessButtonStyle { public static var borderless: BorderlessButtonStyle { BorderlessButtonStyle() } }

public protocol ToggleStyle {}
public struct CheckboxToggleStyle: ToggleStyle {}
extension ToggleStyle where Self == CheckboxToggleStyle { public static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() } }

public protocol TextFieldStyle {}
public struct RoundedBorderTextFieldStyle: TextFieldStyle {}
public struct PlainTextFieldStyle: TextFieldStyle {}
extension TextFieldStyle where Self == PlainTextFieldStyle { public static var plain: PlainTextFieldStyle { PlainTextFieldStyle() } }
extension TextFieldStyle where Self == RoundedBorderTextFieldStyle { public static var roundedBorder: RoundedBorderTextFieldStyle { RoundedBorderTextFieldStyle() } }

public protocol FormStyle {}
public struct GroupedFormStyle: FormStyle {}
extension FormStyle where Self == GroupedFormStyle { public static var grouped: GroupedFormStyle { GroupedFormStyle() } }

public struct KeyboardShortcut {
    public static let defaultAction = KeyboardShortcut()
    public static let cancelAction = KeyboardShortcut()
}
public struct SubmitTriggers: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let text = SubmitTriggers(rawValue: 1)
}

// MARK: Property wrappers

@propertyWrapper @dynamicMemberLookup
public struct Binding<Value> {
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {}
    public init(projectedValue: Binding<Value>) {}
    public var wrappedValue: Value {
        get { fatalError() }
        nonmutating set {}
    }
    public var projectedValue: Binding<Value> { self }
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> { fatalError() }
}

@propertyWrapper
public struct State<Value> {
    public init(wrappedValue value: Value) {}
    public init(initialValue value: Value) {}
    public var wrappedValue: Value {
        get { fatalError() }
        nonmutating set {}
    }
    public var projectedValue: Binding<Value> { fatalError() }
}

@propertyWrapper
public struct ObservedObject<ObjectType: ObservableObject> {
    @dynamicMemberLookup
    public struct Wrapper {
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> { fatalError() }
    }
    public init(wrappedValue: ObjectType) { self.wrappedValue = wrappedValue }
    public var wrappedValue: ObjectType
    public var projectedValue: Wrapper { Wrapper() }
}

// MARK: Vues

public struct Text: _PrimitiveView {
    public enum TruncationMode { case head, tail, middle }
    public static func + (lhs: Text, rhs: Text) -> Text { lhs }
    public func italic() -> Text { self }
    public init(_ key: LocalizedStringKey) {}
    @_disfavoredOverload public init<S: StringProtocol>(_ content: S) {}
}

public struct Image: _PrimitiveView {
    public init(systemName: String) {}
}

public struct Spacer: _PrimitiveView { public init() {} }
public struct Divider: _PrimitiveView { public init() {} }

public struct Label<Title: View, Icon: View>: _PrimitiveView {}
extension Label where Title == Text, Icon == Image {
    public init(_ titleKey: LocalizedStringKey, systemImage name: String) {}
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage name: String) {}
}

public struct Button<Label: View>: _PrimitiveView {
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {}
}
extension Button where Label == Text {
    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {}
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) {}
}

public struct Toggle<Label: View>: _PrimitiveView {
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {}
}
extension Toggle where Label == Text {
    public init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) {}
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) {}
}

public struct TextField<Label: View>: _PrimitiveView {}
extension TextField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {}
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {}
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>) {}
}

public struct Picker<Label: View, SelectionValue: Hashable, Content: View>: _PrimitiveView {}
extension Picker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
}

public struct Stepper<Label: View>: _PrimitiveView {}
extension Stepper where Label == Text {
    public init<V: Strideable>(_ titleKey: LocalizedStringKey, value: Binding<V>, in bounds: ClosedRange<V>,
                               step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
}

public struct HStack<Content: View>: _PrimitiveView {
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}
public struct VStack<Content: View>: _PrimitiveView {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}
public struct Group<Content: View>: _PrimitiveView {
    public init(@ViewBuilder content: () -> Content) {}
}
public struct ScrollView<Content: View>: _PrimitiveView {
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {}
}
public struct List<SelectionValue: Hashable, Content: View>: _PrimitiveView {}
extension List where SelectionValue == Never {
    public init(@ViewBuilder content: () -> Content) {}
}
public struct Form<Content: View>: _PrimitiveView {
    public init(@ViewBuilder content: () -> Content) {}
}
public struct Section<Parent, Content, Footer> {}
extension Section: View where Parent: View, Content: View, Footer: View {
    public var body: Never { fatalError() }
}
extension Section where Parent == Text, Content: View, Footer == EmptyView {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
}

public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content> {}
extension ForEach: View where Content: View {
    public var body: Never { fatalError() }
}
extension ForEach where ID == Data.Element.ID, Content: View, Data.Element: Identifiable {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {}
}
extension ForEach where Content: View {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {}
}
extension ForEach where Content: View {
    public init<C>(_ data: Binding<C>, @ViewBuilder content: @escaping (Binding<C.Element>) -> Content)
        where Data == LazyMapSequence<C.Indices, (C.Index, ID)>, ID == C.Element.ID, C: MutableCollection,
              C: RandomAccessCollection, C.Element: Identifiable, C.Index: Hashable {}
}

// MARK: Modificateurs

extension View {
    public func font(_ font: Font?) -> some View { self }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View { self }
    public func padding(_ length: CGFloat) -> some View { self }
    public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View { self }
    public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View { self }
    public func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                      minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil,
                      alignment: Alignment = .center) -> some View { self }
    public func fixedSize(horizontal: Bool, vertical: Bool) -> some View { self }
    public func fixedSize() -> some View { self }
    public func lineLimit(_ number: Int?) -> some View { self }
    public func truncationMode(_ mode: Text.TruncationMode) -> some View { self }
    public func textFieldStyle<S: TextFieldStyle>(_ style: S) -> some View { self }
    public func toggleStyle<S: ToggleStyle>(_ style: S) -> some View { self }
    public func buttonStyle<S: PrimitiveButtonStyle>(_ style: S) -> some View { self }
    public func formStyle<S: FormStyle>(_ style: S) -> some View { self }
    public func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping (() -> Void)) -> some View { self }
    public func disabled(_ disabled: Bool) -> some View { self }
    public func opacity(_ opacity: Double) -> some View { self }
    public func help(_ textKey: LocalizedStringKey) -> some View { self }
    @_disfavoredOverload public func help<S: StringProtocol>(_ text: S) -> some View { self }
    public func clipShape<S: Shape>(_ shape: S, style: FillStyle = FillStyle()) -> some View { self }
    public func onHover(perform action: @escaping (Bool) -> Void) -> some View { self }
    public func labelsHidden() -> some View { self }
    public func keyboardShortcut(_ shortcut: KeyboardShortcut) -> some View { self }
    public func tag<V: Hashable>(_ tag: V) -> some View { self }
    public func contentShape<S: Shape>(_ shape: S, eoFill: Bool = false) -> some View { self }
    public func background<S: ShapeStyle, T: InsettableShape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { self }
    public func overlay<Overlay: View>(_ overlay: Overlay, alignment: Alignment = .center) -> some View { self }
}

extension CGFloat {
    public static var infinity: CGFloat { CGFloat.greatestFiniteMagnitude }
}

// MARK: Pont vers AppKit

public struct NSHostingSizingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let minSize = NSHostingSizingOptions(rawValue: 1)
    public static let intrinsicContentSize = NSHostingSizingOptions(rawValue: 2)
    public static let maxSize = NSHostingSizingOptions(rawValue: 4)
    public static let preferredContentSize = NSHostingSizingOptions(rawValue: 8)
}

extension NSColor {
    public convenience init(_ color: Color) { self.init(srgbRed: 0, green: 0, blue: 0, alpha: 1) }
}

open class NSHostingController<Content: View>: NSViewController {
    public init(rootView: Content) { self.rootView = rootView }
    public var rootView: Content
    public var sizingOptions: NSHostingSizingOptions = []
}
