import XCTest
@testable import DocumentUI

final class DocumentUITests: XCTestCase {
    func testBasic() throws {
        struct Document: TextDocument {
            let parameter: Int
            var textBody: some TextDocument {
                "Parameter equals \(parameter)"
            }
        }
        let value = 11
        let document = Document(parameter: value)
        XCTAssertEqual("\(document)", "Parameter equals \(value)")
    }

    func testObjectDescription() {
        let object = SomeObject()
        object.items = ["key1": "value1", "key2": "value2", "key3": "value3"]
        print(object)
        print(object.items)
    }

    func testMarkdownGenerator() {
        print("\(MarkdownDocument())")
    }
}

final class SomeObject: CustomStringConvertible {
    var items: [String: String]

    init(items: [String : String] = [:]) {
        self.items = items
    }

    var description: String {
        "\(Description(object: self))"
    }

    struct Description: TextDocument {
        let object: SomeObject

        var textBody: some TextDocument {
            "[\n"
            ForEach(object.items, separator: "\n") { element in
                switch element.key {
                case "key1": "🌍 -> \(element.value)"
                case "key2": "🐢 -> \(element.value)"
                case "key3": "🎃 -> \(element.value)"
                default: "\(element.key) -> \(element.value)"
                }
            }.indent(4)
            "\n]"
        }
    }
}

struct MarkdownDocument: TextDocument {
    var textBody: some TextDocument {
        Joined(separator: "\n\n") {
            Header(text: "Fancy Header Title", level: 1)
            OrderedList(values: ["A big leaf", "Some small leaves:", "A medium sized leaf that maybe was pancake shaped"])
            UnorderedList(values: ["Blueberries", "Apples", "Banana"], bullet: "-")
            Code(lang: "swift") {
                """
                func yeah() -> NSAttributedString {
                    // TODO: Write code
                }
                """
            }
        }
    }
}

struct OrderedList: TextDocument {
    let values: [String]
    var textBody: some TextDocument {
        ForEach(enumerated: values, separator: "\n") { (i, element) in
            "\(i + 1). \(element)"
        }
    }
}
struct UnorderedList: TextDocument {
    let values: [String]
    let bullet: String
    var textBody: some TextDocument {
        ForEach(enumerated: values, separator: "\n") { (i, element) in
            "\(bullet) \(element)"
        }
    }
}
struct Header: TextDocument {
    let text: String
    let level: Int
    var textBody: some TextDocument {
        "#".repeating(level).suffix(" ")
        text
    }
}
struct Code<Body>: TextDocument where Body: TextDocument {
    let lang: String
    @TextDocumentBuilder let body: () -> Body
    var textBody: some TextDocument {
        "```\(lang)".suffix("\n")
        body()
        "```".prefix("\n")
    }
}
