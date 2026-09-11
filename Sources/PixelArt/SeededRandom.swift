/// Stable authoring randomness, independent of Swift's randomized Hasher and game simulation RNG.
public struct SeededRandom {
    private var state: UInt64
    public init(seed: UInt64, stream: String = "") {
        var hash: UInt64 = 14695981039346656037
        for byte in stream.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        state = seed ^ hash
    }
    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
    public mutating func integer(_ range: Range<Int>) -> Int {
        precondition(!range.isEmpty)
        return range.lowerBound + Int(next() % UInt64(range.count))
    }
    public mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
    public mutating func choose<T>(_ options: [T]) -> T { options[integer(0..<options.count)] }
}
