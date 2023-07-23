//
//  File.swift
//  
//
//  Created by Denis Koryttsev on 23.07.23.
//

import CoreUI

public struct TupleDocument<T>: TextDocument {
    let acceptor: (DocumentVisitor) -> Void
    init(_ acceptor: @escaping (DocumentVisitor) -> Void) { self.acceptor = acceptor }
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
            modifiers.append(modifier.modify(content:))
        }
        public mutating func build() -> String {
            let builder = Builder()
            document.acceptor(builder)
            guard !builder.result.isEmpty else { return "" } // TODO: should check that all elements is NullDocument
            for mod in modifiers { mod(&builder.result) }
            return builder.result
        }

        final class Builder: DocumentVisitor {
            var result: String = ""
            func visit<D>(_ document: D) where D : TextDocument {
                var interpolation = D.DocumentInterpolation(document)
                result.append(interpolation.build())
            }
        }
    }
}
