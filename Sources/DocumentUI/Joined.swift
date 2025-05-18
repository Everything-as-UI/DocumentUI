//
//  Joined.swift
//  
//
//  Created by Denis Koryttsev on 23.07.23.
//

import CoreUI

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
    public init<Elements>(separator: Separator, ommitingEmptyElements: Bool = true, elements: Elements) where Elements: Sequence, Elements.Element: TextDocument, T == Elements.Element {
        self.separator = separator
        self.ommitingEmptyElements = ommitingEmptyElements
        self.content = TupleDocument({ elements.forEach($0.visit) })
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
            modifiers.append(modifier.modify(content:))
        }
        public mutating func build() -> String {
            var sepInterpolator = Separator.DocumentInterpolation(document.separator)
            let separator = sepInterpolator.build()
            let builder = ResultBuilder(ommitingEmptyElements: document.ommitingEmptyElements, separator: separator)
            document.content.acceptor(builder)
            guard !builder.result.isEmpty else { return "" }
            for mod in modifiers { mod(&builder.result) }
            return builder.result
        }

        final class ResultBuilder: TextDocumentVisitor {
            let ommitingEmptyElements: Bool
            let separator: String
            var result = ""
            var shouldAppendSeparator: Bool = false

            init(ommitingEmptyElements: Bool, separator: String) {
                self.ommitingEmptyElements = ommitingEmptyElements
                self.separator = separator
            }

            func visit<D>(_ document: D) where D : TextDocument {
                var interpolation = D.DocumentInterpolation(document)
                let part = interpolation.build()
                guard ommitingEmptyElements, part.isEmpty else {
                    if shouldAppendSeparator {
                        result.append(separator)
                        result.append(part)
                    } else {
                        result.append(part)
                    }
                    shouldAppendSeparator = true
                    return
                }
            }
        }
    }
}
