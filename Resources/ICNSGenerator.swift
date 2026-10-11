import Foundation

struct IconEntry {
    let type: String
    let path: String
}

private func bigEndianBytes(_ value: UInt32) -> Data {
    var value = value.bigEndian
    return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
}

let directory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
let output = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "AppIcon.icns"
let entries = [
    IconEntry(type: "icp4", path: "icon_16x16.png"),
    IconEntry(type: "icp5", path: "icon_32x32.png"),
    IconEntry(type: "icp6", path: "icon_32x32@2x.png"),
    IconEntry(type: "ic07", path: "icon_128x128.png"),
    IconEntry(type: "ic08", path: "icon_256x256.png"),
    IconEntry(type: "ic09", path: "icon_512x512.png"),
    IconEntry(type: "ic10", path: "icon_512x512@2x.png")
]

var body = Data()
for entry in entries {
    let url = URL(fileURLWithPath: directory).appendingPathComponent(entry.path)
    let png = try Data(contentsOf: url)
    body.append(entry.type.data(using: .ascii)!)
    body.append(bigEndianBytes(UInt32(png.count + 8)))
    body.append(png)
}

var result = Data("icns".utf8)
result.append(bigEndianBytes(UInt32(body.count + 8)))
result.append(body)
try result.write(to: URL(fileURLWithPath: output), options: .atomic)
