import Foundation
import CoreUI
import CommonUI

public typealias TextDocumentBuilder = ViewBuilder
public typealias NullDocument = NullView
public typealias _ModifiedDocument<Content, Modifier> = _ModifiedContent<Content, Modifier>
public typealias _ConditionalDocument<TrueContent, FalseContent> = _ConditionalContent<TrueContent, FalseContent>

@_exported import struct CoreUI.ForEach
@_exported import struct CoreUI.Group

@_typeEraser(AnyTextDocument)
public protocol TextDocument {
    associatedtype DocumentInterpolation: DocumentInterpolationProtocol = DefaultDocumentInterpolation<Self>
    where DocumentInterpolation.View == Self, DocumentInterpolation.Result == String
    associatedtype TextBody: TextDocument
    @TextDocumentBuilder var textBody: TextBody { get }
}
public protocol DocumentInterpolationProtocol: ViewInterpolationProtocol where ModifyContent == String {}
public protocol TextDocumentModifier: ViewModifier where Modifiable == String {}

extension TextDocument {
    func buildText() -> String {
        var interpolation = DocumentInterpolation(self)
        return interpolation.build()
    }
}
extension String.StringInterpolation {
    public mutating func appendInterpolation<Document>(_ document: Document) where Document: TextDocument {
        appendLiteral(document.buildText())
    }
}

public struct DefaultDocumentInterpolation<Document>: DocumentInterpolationProtocol where Document: TextDocument {
    public typealias View = Document
    public typealias ModifyContent = Document.TextBody.DocumentInterpolation.ModifyContent
    var base: Document.TextBody.DocumentInterpolation
    @_spi(DocumentUI)
    public init(_ document: Document) {
        self.base = Document.TextBody.DocumentInterpolation(document.textBody)
    }
    @_spi(DocumentUI)
    public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
        base.modify(modifier)
    }
    @_spi(DocumentUI)
    public mutating func build() -> Document.TextBody.DocumentInterpolation.Result {
        base.build()
    }
}

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

///

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

public struct AnyTextDocument: TextDocument {
    let interpolation: AnyInterpolation<String, String>
    public init<T>(_ document: T) where T: TextDocument {
        self.interpolation = AnyInterpolation(T.DocumentInterpolation(document))
    }
    public init<T>(erasing document: T) where T: TextDocument {
        self.init(document)
    }
    public var textBody: Never { fatalError() }
    @_spi(DocumentUI)
    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias ModifyContent = String
        let document: AnyTextDocument
        public init(_ document: AnyTextDocument) {
            self.document = document
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            document.interpolation.modify(modifier)
        }
        public func build() -> String { document.interpolation.build() }
    }
}

extension ForEach: TextDocument where Content: TextDocument {
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
            modifiers.append({ modifier.modify(content: &$0) })
        }
        public mutating func build() -> Content.DocumentInterpolation.Result {
            var result = ""
            for element in document.data {
                var interpolation = Content.DocumentInterpolation(document.content(element))
                result.append(interpolation.build())
            }
            for mod in modifiers { mod(&result) } // modifiers should not be applied if all elements are NullDocument
            return result
        }
    }
}

public struct Joined<Separator, T> {
    let separator: Separator
    let ommitingEmptyElements: Bool
    let content: TupleDocument<T>
    public init(separator: Separator, ommitingEmptyElements: Bool = true, @TextDocumentBuilder content: () -> TupleDocument<T>) {
        self.separator = separator
        self.ommitingEmptyElements = ommitingEmptyElements
        self.content = content()
    }
    public init(@TextDocumentBuilder content: () -> TupleDocument<T>) where Separator == NullDocument {
        self.init(separator: NullDocument(), content: content)
    }
    public init<Element>(separator: Separator, ommitingEmptyElements: Bool = true, elements: [Element]) where Element: TextDocument {
        self.separator = separator
        self.ommitingEmptyElements = ommitingEmptyElements
        self.content = TupleDocument({ elements.map({ $0.buildText() }) })
    }
}
extension Joined: TextDocument where Separator: TextDocument {
    public var textBody: Never { fatalError() }
    @_spi(DocumentUI)
    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias View = Joined<Separator, T>
        public typealias ModifyContent = String
        let document: Joined<Separator, T>
        var modifiers: [(inout String) -> Void] = []
        public init(_ document: Joined<Separator, T>) {
            self.document = document
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            modifiers.append({ modifier.modify(content: &$0) })
        }
        public mutating func build() -> String {
            var sepInterpolator = Separator.DocumentInterpolation(document.separator)
            let items = document.content.build()
            var result: String
            if document.ommitingEmptyElements {
                result = items.lazy
                    .compactMap({ $0.count > 0 ? $0 : nil })
                    .joined(separator: sepInterpolator.build())
            } else {
                result = items.joined(separator: sepInterpolator.build())
            }
            for mod in modifiers { mod(&result) }
            return result
        }
    }
}

public struct TupleDocument<T>: TextDocument {
    let build: () -> [String]
    init(_ build: @escaping () -> [String]) { self.build = build }
    public var textBody: Never { fatalError() }
    @_spi(DocumentUI)
    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias View = TupleDocument<T>
        public typealias ModifyContent = String
        let document: TupleDocument<T>
        var modifiers: [(inout String) -> Void] = []
        public init(_ document: TupleDocument<T>) {
            self.document = document
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            modifiers.append({ modifier.modify(content: &$0) })
        }
        public mutating func build() -> String {
            var result = document.build().joined(separator: "")
            for mod in modifiers { mod(&result) }
            return result
        }
    }
}

///

public struct Repeating {
    let count: Int
}
extension Repeating: TextDocumentModifier {
    public func modify(content: inout String) {
        content = String(repeating: content, count: count)
    }
}
public struct Indenting {
    let count: Int
}
extension Indenting: TextDocumentModifier {
    public func modify(content: inout String) {
        let indentString = String(repeating: " ", count: count)
        content = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { indentString + $0 }
            .joined(separator: "\n")
    }
}
extension TextDocument {
    public func repeating(_ count: Int) -> _ModifiedDocument<Self, Repeating> {
        _ModifiedDocument(self, modifier: Repeating(count: count))
    }
    public func indent(_ count: Int) -> _ModifiedDocument<Self, Indenting> {
        _ModifiedDocument(self, modifier: Indenting(count: count))
    }
}

public struct Prefix<T>: TextDocumentModifier where T: TextDocument {
    let value: T
    public func modify(content: inout String) {
        content = value.buildText() + content
    }
}
public struct Suffix<T>: TextDocumentModifier where T: TextDocument {
    let value: T
    public func modify(content: inout String) {
        content.append(value.buildText())
    }
}
extension TextDocument {
    public func prefix<T>(_ value: T) -> _ModifiedDocument<Self, Prefix<T>> {
        _ModifiedDocument(self, modifier: Prefix(value: value))
    }
    public func suffix<T>(_ value: T) -> _ModifiedDocument<Self, Suffix<T>> {
        _ModifiedDocument(self, modifier: Suffix(value: value))
    }
}
public struct PercentEncoding: TextDocumentModifier {
    let characterSet: CharacterSet
    public func modify(content: inout String) {
        if let encoding = content.addingPercentEncoding(withAllowedCharacters: characterSet) {
            content = encoding
        }
    }
}
extension TextDocument {
    public func percentEncoding(_ characterSet: CharacterSet) -> _ModifiedDocument<Self, PercentEncoding> {
        _ModifiedDocument(self, modifier: PercentEncoding(characterSet: characterSet))
    }
}
public struct ConditionalModifier<Base>: TextDocumentModifier where Base: ViewModifier, Base.Modifiable == String {
    let base: Base
    let condition: (String) -> Bool
    public func modify(content: inout String) {
        guard condition(content) else { return }
        base.modify(content: &content)
    }
}
extension TextDocument {
    public func modifier<M>(_ modifier: M, where condition: @escaping (String) -> Bool) -> _ModifiedDocument<Self, ConditionalModifier<M>> {
        self.modifier(ConditionalModifier(base: modifier, condition: condition))
    }
}

public struct _ConditionalModified<Content> {
    let condition: (String) -> Bool
    let content: Content
}
extension _ConditionalModified: TextDocument where Content: TextDocument {
    public var textBody: some TextDocument { content }
    @_spi(DocumentUI)
    public struct DocumentInterpolation: DocumentInterpolationProtocol {
        public typealias View = _ConditionalModified<Content>
        public typealias ModifyContent = String
        var base: Content.DocumentInterpolation
        let condition: (String) -> Bool
        public init(_ document: _ConditionalModified<Content>) {
            self.base = Content.DocumentInterpolation(document.content)
            self.condition = document.condition
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            base.modify(ConditionalModifier(base: modifier, condition: condition))
        }
        public mutating func build() -> String { base.build() }
    }
}
extension TextDocument {
    public func modifiable(whenContent condition: @escaping (String) -> Bool) -> _ConditionalModified<Self> {
        _ConditionalModified(condition: condition, content: self)
    }
}