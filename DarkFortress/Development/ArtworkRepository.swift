#if DEBUG && targetEnvironment(simulator)
import Foundation
import FortressArt

/// Only the simulator's Admin tools know where source artwork is stored.
enum ArtworkRepository {
    static let root = URL(fileURLWithPath: "/Users/aaronshaver/code/dark-fantasy-base-builder", isDirectory: true)
    static let store = ArtworkStore(root: root)
}
#endif
