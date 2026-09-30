import Foundation
// The approved transparent logo is packaged unchanged; build.sh creates standard icon sizes.
try Data(contentsOf: URL(fileURLWithPath: "Assets/AkkuLogo.png")).write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
