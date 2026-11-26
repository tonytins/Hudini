// The demo's own content. Hudini leaves CST text to games, and the demo reads its text with SwiftCST,
// as games do, so this lives here rather than in Hudini's tests.

import Foundation
import Hudini
import SwiftCST
import Testing

private func demoResource(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../../Sources/hudini-demo/Resources/\(name)")
        .standardizedFileURL
}

@Test func theDemoHasTextForEveryStringItsInterfacesUse() throws {
    let directory = demoResource("uitext")
    let text = UIText(directory: directory)
    let tableIDs = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        .compactMap { name in name.split(separator: "_").first.flatMap { Int($0) } }
    let documents = [
        try UIScript(contentsOf: demoResource("livepanel1024.uix")),
        try UIScript(contentsOf: demoResource("statspanel.uix")),
        try UIScript(contentsOf: demoResource("optionspanel.uix")),
        try UIScript(contentsOf: demoResource("movelot.uix")),
        try UIScript(uisContentsOf: demoResource("lemonadestand.uis")),
        try UIScript(uisContentsOf: demoResource("debugbar.uis"))
    ]

    #expect(tableIDs.count == 6)
    for id in tableIDs {
        #expect(try text.table(for: id)?.problems == [])
    }
    for document in documents {
        let view = UIView(script: document) { resource in
            resource.table.split(separator: ":").last.flatMap { Int($0) }
                .flatMap { try? text.textIfPresent(for: $0, key: resource.index) }
        }
        #expect(view.missingStrings.isEmpty)
    }
}
