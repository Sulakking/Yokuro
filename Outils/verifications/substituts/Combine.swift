// Substitut minimal de Combine pour vérifier les types sous Linux.
public protocol ObservableObject: AnyObject {}

public final class AnyCancellable {
    public init() {}
    public func cancel() {}
}

@propertyWrapper
public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(initialValue: Value) { self.wrappedValue = initialValue }

    public struct Publisher {
        public func sink(receiveValue: @escaping (Value) -> Void) -> AnyCancellable { AnyCancellable() }
    }
    public var projectedValue: Publisher { Publisher() }
}
