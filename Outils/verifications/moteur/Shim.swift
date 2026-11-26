import Foundation

// Deux API propres à macOS, remplacées ici pour pouvoir exécuter le moteur sous Linux.
extension NSString {
    var abbreviatingWithTildeInPath: String {
        let home = NSHomeDirectory()
        let path = self as String
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

var trashed: [String] = []

extension FileManager {
    func trashItem(at url: URL, resultingItemURL: Int?) throws {
        trashed.append(url.lastPathComponent)
        try removeItem(at: url)
    }
}
