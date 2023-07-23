//
//  Modifiers.swift
//  
//
//  Created by Denis Koryttsev on 23.07.23.
//

import Foundation
import CoreUI

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
    public func prefix<T>(@TextDocumentBuilder _ content: () -> T) -> _ModifiedDocument<Self, Prefix<T>> {
        _ModifiedDocument(self, modifier: Prefix(value: content()))
    }
    public func suffix<T>(_ value: T) -> _ModifiedDocument<Self, Suffix<T>> {
        _ModifiedDocument(self, modifier: Suffix(value: value))
    }
    public func suffix<T>(@TextDocumentBuilder _ content: () -> T) -> _ModifiedDocument<Self, Suffix<T>> {
        _ModifiedDocument(self, modifier: Suffix(value: content()))
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
