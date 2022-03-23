import IOModule

public enum ImageFormat: String, CaseIterable {

  case jpeg
  case png
//  case gif

  public init<T: Read & Seek>(input: inout T) throws {
    self = try Self.allCases.first(
      where: { format in
        try format.match(&input)
      })!
//      .unwrap("No matched ImageFormat.")
  }

  var headerLength: Int {
    switch self {
//    case .gif: return 6
    case .jpeg: return 2
    case .png: return 8
    }
  }

  private func match<D: Read & Seek>(_ reader: inout D) throws -> Bool {
    try reader.seek(toOffset: 0, from: .start)
    switch self {
    case .jpeg:
      let header = try reader.readInteger(endian: .big, as: UInt16.self)
      return header == 0xffd8
    case .png:
      let header = try reader.readInteger(endian: .big, as: UInt64.self)
      return header == 0x89504e470d0a1a0a
    }
  }

  public var mimeType: String {
    "image/\(rawValue)"
  }

}
