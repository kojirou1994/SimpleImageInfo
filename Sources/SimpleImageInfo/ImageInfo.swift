import IOModule
import Precondition

/*
 Note:
 https://github.com/xiph/flac/blob/452a44777892086892feb8ed7f1156e9b897b5c3/src/share/grabbag/picture.c
 */

public enum ImageInfoParseError: Error {
  case invalidPNG
  case invalidJPEG
}

extension Seek {
  mutating func unreadBytesCount() throws -> Int64 {
    try streamLength() - currentOffset()
  }
}

extension Read where Self: Seek {
  mutating func readJPEGNumber() throws -> UInt32 {
    try UInt32(readInteger() as UInt16)
  }
}

public struct ImageInfo {
  public let format: ImageFormat
  public let width: UInt32
  public let height: UInt32
  public let depth: UInt8
  public let colors: UInt32

  public init<T: Read & Seek & AnyObject>(input: T) throws {
    var ref = input
    try self.init(input: &ref)
  }

  public init<T: Read & Seek>(input: inout T) throws {
    format = try ImageFormat(input: &input)
    switch format {
    case .png:
      var height: UInt32?
      var width: UInt32?
      var depth: UInt8 = 0
      var colors: UInt32?
      var needPalette = false
//      try preconditionOrThrow(reader.count >= 25, ImageInfoParseError.invalidPNG)
      while try input.unreadBytesCount() > 12 {
        let clen = try input.readInteger() as UInt32
        let tag = try input.readInteger() as UInt32
        if clen == 13, tag == 0x49484452 {
          // IHDR
          width = try input.readInteger()
          height = try input.readInteger()
          depth = try input.readByte()
          let colorType = try input.readByte()
          try input.skip(1 + 1 + 1 + 4)
          if colorType == 3 {
            /* even though the bit depth for color_type==3 can be 1,2,4,or 8,
             * the spec in 11.2.2 of http://www.w3.org/TR/PNG/ says that the
             * sample depth is always 8
             */
            depth = 3 * 8
            needPalette = true
          } else {
            switch colorType {
            case 0:
              /* greyscale, 1 sample per pixel */
              break
            case 2:
              /* truecolor, 3 samples per pixel */
              depth *= 3
            case 4:
              /* greyscale+alpha, 2 samples per pixel */
              depth *= 2
            case 6:
              /* truecolor+alpha, 4 samples per pixel */
              depth *= 4
            default: break
            }
            colors = 0
            break
          }
        } else if needPalette, tag == 0x504c5445 {
          // PLTE
          colors = clen / 3
          break
        } else if try (clen + 12) > input.unreadBytesCount() {
          throw ImageInfoParseError.invalidPNG
        } else {
          try input.skip(Int(4+clen))
        }
      }
      if width == nil {
        throw ImageInfoParseError.invalidPNG
      }
      self.width = width!
      self.height = height!
      self.depth = depth
      self.colors = colors!
    case .jpeg:
      /* c.f. http://www.w3.org/Graphics/JPEG/itu-t81.pdf and Q22 of http://www.faqs.org/faqs/jpeg-faq/part1/ */
      var height: UInt32?
      var width: UInt32?
      var depth: UInt8 = 0
      var colors: UInt32?
      while true {
        /* look for sync FF byte */
        while try input.readByte() != 0xff {
        }
        if try input.isAtEnd() {
          break
        }
        /* eat any extra pad FF bytes before marker */
        while try input.readByte() == 0xff {
        }
        if try input.isAtEnd() {
          break
        }
        try input.skip(-1)
        let currentByte = try input.readByte()
        if currentByte == 0xda || currentByte == 0xd9 {
          throw ImageInfoParseError.invalidJPEG
        } else if Self.jpegTag.contains(currentByte) {
          if try input.unreadBytesCount() < 2 {
            throw ImageInfoParseError.invalidJPEG
          } else {
            let clen = try input.readJPEGNumber()
            if try clen < 8 || input.unreadBytesCount() < clen {
              throw ImageInfoParseError.invalidJPEG
            }
            depth = try input.readByte()
            height = try input.readJPEGNumber()
            width = try input.readJPEGNumber()
            depth *= try input.readByte()
            colors = 0
            break
          }
        } else { // skip it
          if try input.unreadBytesCount() < 2 {
            throw ImageInfoParseError.invalidJPEG
          } else {
            let clen = try input.readJPEGNumber()
            if try clen < 2 || input.unreadBytesCount() < clen {
              throw ImageInfoParseError.invalidJPEG
            }
            try input.skip(Int(clen-2))
          }
        }
      }
      if width == nil {
        throw ImageInfoParseError.invalidJPEG
      }
      self.width = width!
      self.height = height!
      self.depth = depth
      self.colors = colors!
    }
  }

  static let jpegTag: Set<UInt8> = [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf]
}
