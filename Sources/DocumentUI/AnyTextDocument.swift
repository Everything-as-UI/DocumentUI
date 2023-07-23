//
//  AnyTextDocument.swift
//  
//
//  Created by Denis Koryttsev on 23.07.23.
//

import Foundation
import CoreUI
import CommonUI

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
extension AnyTextDocument: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.interpolation = AnyInterpolation(String.DocumentInterpolation(value))
    }
}
extension AnyTextDocument: ExpressibleByStringInterpolation {
    public init(stringInterpolation: DefaultStringInterpolation) {
        self.init(stringLiteral: stringInterpolation.description)
    }
}
