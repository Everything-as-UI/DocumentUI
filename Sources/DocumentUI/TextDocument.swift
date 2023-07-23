//
//  TextDocument.swift
//  
//
//  Created by Denis Koryttsev on 23.07.23.
//

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
