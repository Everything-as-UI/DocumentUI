import Foundation
import CoreUI
import CommonUI

extension NullDocument: TextDocument {
    public var textBody: Never { fatalError() }
    @_spi(DocumentUI)
    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias View = NullDocument
        public typealias ModifyContent = String
        public init(_ document: NullDocument) {}
        public func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {}
        public func build() -> String { "" }
    }
}

extension _ModifiedDocument: TextDocument where Content: TextDocument, Modifier: TextDocumentModifier {
    public var textBody: Never { fatalError() }
    @_spi(DocumentUI)
    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias View = _ModifiedDocument<Content, Modifier>
        public typealias ModifyContent = String
        var base: Content.DocumentInterpolation
        public init(_ document: _ModifiedDocument<Content, Modifier>) {
            self.base = Content.DocumentInterpolation(document.content)
            self.base.modify(document.modifier)
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            base.modify(modifier)
        }
        public mutating func build() -> Content.DocumentInterpolation.Result {
            base.build()
        }
    }
}
extension TextDocument {
    public func modifier<T>(_ modifier: T) -> _ModifiedDocument<Self, T> {
        _ModifiedDocument(self, modifier: modifier)
    }
}

extension _ConditionalDocument: TextDocument
where TrueContent: TextDocument, FalseContent: TextDocument,
      TrueContent.DocumentInterpolation.ModifyContent == FalseContent.DocumentInterpolation.ModifyContent,
      TrueContent.DocumentInterpolation.Result == FalseContent.DocumentInterpolation.Result {
    public var textBody: Never { fatalError() }
    @_spi(DocumentUI)
    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias View = _ConditionalDocument<TrueContent, FalseContent>
        public typealias ModifyContent = String
        enum Condition {
        case first(TrueContent.DocumentInterpolation)
        case second(FalseContent.DocumentInterpolation)
        }
        var base: Condition
        public init(_ document: _ConditionalDocument<TrueContent, FalseContent>) {
            switch document.condition {
            case .first(let first): self.base = .first(TrueContent.DocumentInterpolation(first))
            case .second(let second): self.base = .second(FalseContent.DocumentInterpolation(second))
            }
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            switch base {
            case .first(var trueContent):
                trueContent.modify(modifier)
                self.base = .first(trueContent)
            case .second(var falseContent):
                falseContent.modify(modifier)
                self.base = .second(falseContent)
            }
        }
        public func build() -> TrueContent.DocumentInterpolation.Result {
            switch base {
            case .first(var trueContent): return trueContent.build()
            case .second(var falseContent): return falseContent.build()
            }
        }
    }
}

extension Never: TextDocument {
    public var textBody: Never { fatalError() }
    @_spi(DocumentUI)
    public enum DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias View = Never
        public typealias ModifyContent = String
        public init(_ document: Never) { fatalError() }
        public func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {}
        public func build() -> String { fatalError() }
    }
}
@_spi(DocumentUI)
extension Optional: TextDocument where Wrapped: TextDocument {
    public var textBody: some TextDocument {
        switch self {
        case .none: NullDocument()
        case .some(let wrapped): wrapped
        }
    }
}

extension String: TextDocument {
    public var textBody: Never { fatalError() }
    @_spi(DocumentUI)
    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias ModifyContent = String
        var document: String
        public init(_ document: String) {
            self.document = document
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, String == M.Modifiable {
            modifier.modify(content: &document)
        }
        public func build() -> String { document }
    }
}

extension Group: TextDocument where Content: TextDocument {
    public var textBody: some TextDocument { body }
}

extension ForEach: TextDocument where Content: TextDocument {
    public init<D, C>(enumerated data: D, separator: String, @TextDocumentBuilder content: @escaping ((offset: Int, element: D.Element)) -> C) where D: Collection, Data == EnumeratedSequence<D>, Content == _ModifiedContent<C, Prefix<String>> {
        self.init(data.enumerated()) { el in
            content((el.offset, el.element)).prefix(el.offset > 0 ? separator : "")
        }
    }
    public init<D, C>(_ data: D, separator: String, @TextDocumentBuilder content: @escaping (D.Element) -> C) where D: Collection, Data == EnumeratedSequence<D>, Content == _ModifiedContent<C, Prefix<String>> {
        self.init(data.enumerated()) { el in
            content(el.element).prefix(el.offset > 0 ? separator : "")
        }
    }
    public var textBody: Never { fatalError() }
    @_spi(DocumentUI)
    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias View = ForEach<Data, Content>
        let document: View
        var modifiers: [(inout String) -> Void] = []
        public init(_ document: ForEach<Data, Content>) {
            self.document = document
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            modifiers.append(modifier.modify(content:))
        }
        public mutating func build() -> Content.DocumentInterpolation.Result {
            var result = ""
            var hasElements = false
            for element in document.data {
                hasElements = true
                var interpolation = Content.DocumentInterpolation(document.content(element))
                result.append(interpolation.build())
            }
            guard hasElements else { return "" }
            for mod in modifiers { mod(&result) } // modifiers should not be applied if all elements are NullDocument
            return result
        }
    }
}

/// - Environment

extension ViewWithEnvironmentValue: TextDocument where Content: TextDocument {
    public var textBody: Never { fatalError() }

    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias View = ViewWithEnvironmentValue<Content, V>
        public typealias ModifyContent = Content.DocumentInterpolation.ModifyContent
        let keyPath: WritableKeyPath<EnvironmentValues, V>
        let value: V
        var base: Content.DocumentInterpolation
        @_spi(DocumentUI)
        public init(_ document: View) {
            self.keyPath = document.keyPath
            self.value = document.value
            self.base = EnvironmentValues.withValue(document.value, at: document.keyPath) {
                Content.DocumentInterpolation(document.content)
            }
        }
        @_spi(DocumentUI)
        public mutating func modify<M>(_ modifier: M) where M : CoreUI.ViewModifier, ModifyContent == M.Modifiable {
            base.modify(modifier)
        }
        @_spi(DocumentUI)
        public mutating func build() -> Content.DocumentInterpolation.Result {
            return EnvironmentValues.withValue(value, at: keyPath) {
                base.build()
            }
        }
    }
}

extension TextDocument {
    public func environment<V>(
        _ keyPath: WritableKeyPath<EnvironmentValues, V>,
        _ value: V
    ) -> some TextDocument {
        ViewWithEnvironmentValue(keyPath, value: value, content: self)
    }
}
