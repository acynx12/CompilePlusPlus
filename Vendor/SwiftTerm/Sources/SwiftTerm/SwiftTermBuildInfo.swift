// The upstream package normally generates this file with a build-tool plugin.
// Compile++ vendors the library source, so a fixed local identity keeps the
// package fully self-contained and avoids requiring that plugin.
public enum SwiftTermBuildInfo {
    public static let tag: String? = "vendored"
    public static let branch: String? = "Compile++"
    public static let commit: String? = "4dcf5278fde40af60c36f667d8a472a90b38b247"
    public static let hasUncommittedChanges: Bool? = false
    static let version = "2.0"
}

// The generated upstream table answers optional XTGETTCAP queries. Compile++
// does not need that extension for Vim/GDB, so the vendored build uses an empty
// table and remains free of build-tool plugins.
enum SwiftTermTerminfo {
    static let xtgettcapReplies: [String: String] = [:]
}
