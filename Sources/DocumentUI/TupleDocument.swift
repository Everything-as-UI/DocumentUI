//
//  File.swift
//  
//
//  Created by Denis Koryttsev on 23.07.23.
//

import CoreUI
import CommonUI

public struct TupleDocument<T>: TextDocument {
    let acceptor: (TextDocumentVisitor) -> Void
    
    init(_ acceptor: @escaping (TextDocumentVisitor) -> Void) {
        self.acceptor = acceptor
    }

    #if swift(>=6.0)
    init<each D: TextDocument>(documents: repeat each D) where T == (repeat each D) {
        self.acceptor = { visitor in
            for document in repeat each documents {
                visitor.visit(document)
            }
        }
    }
    #endif
    
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
            let builder = ResultBuilder()
            document.acceptor(builder)
            guard !builder.result.isEmpty else { return "" } // TODO: should check that all elements is NullDocument
            for mod in modifiers { mod(&builder.result) }
            return builder.result
        }

        final class ResultBuilder: TextDocumentVisitor {
            var result: String = ""
            func visit<D>(_ document: D) where D : TextDocument {
                var interpolation = D.DocumentInterpolation(document)
                result.append(interpolation.build())
            }
        }
    }
}
