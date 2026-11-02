extension Int {
    init(clamping value: Float) {
        self.init(clamping: Double(value))
    }

    init(clamping value: Double) {
        if value.isNaN {
            self = 0
        } else if value >= Double(Int32.max) {
            self = Int(Int32.max)
        } else if value <= Double(Int32.min) {
            self = Int(Int32.min)
        } else {
            self = Int(value)
        }
    }
}

extension Character {
    init(codePoint: Int) {
        if let scalarValue = UInt32(exactly: codePoint), let scalar = Unicode.Scalar(scalarValue) {
            self = Character(scalar)
        } else {
            self = "\u{FFFD}"
        }
    }
}
