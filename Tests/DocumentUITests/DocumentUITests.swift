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
}
