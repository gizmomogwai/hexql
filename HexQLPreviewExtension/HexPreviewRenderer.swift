import Foundation
import UniformTypeIdentifiers

enum HexPreviewRenderer {
  static let bytesToPreview = 4096
  private static let bytesPerRow = 16

  static func renderPreview(for fileURL: URL, bundle: Bundle) throws -> RenderedPreview {
    let data = try readPrefix(of: fileURL, byteCount: bytesToPreview)
    let bytes = Array(data)
    let template = try loadStringResource(named: "template", extension: "dhtml", bundle: bundle)
    let html = try Template(template).render(values: [
      "path": htmlEscaped(fileURL.path),
      "hextable": createTable(
        bytes,
        itemsPerRow: bytesPerRow,
        className: "hex",
        formatter: { byte in String(format: "%02X ", byte) },
        filter: { _ in true }
      ),
      "asciitable": createTable(
        bytes,
        itemsPerRow: bytesPerRow,
        className: "ascii",
        formatter: { byte in String(UnicodeScalar(byte)) },
        filter: isAsciiLetterOrDigit
      ),
      "ascii": createAscii(from: bytes),
      "resourcepath": bundle.resourceURL?.absoluteString ?? ""
    ])

    return RenderedPreview(
      htmlData: Data(html.utf8),
      attachments: try loadAttachments(bundle: bundle)
    )
  }

  private static func readPrefix(of fileURL: URL, byteCount: Int) throws -> Data {
    let fileHandle = try FileHandle(forReadingFrom: fileURL)
    defer {
      try? fileHandle.close()
    }

    return try fileHandle.read(upToCount: byteCount) ?? Data()
  }

  private static func createTable(
    _ bytes: [UInt8],
    itemsPerRow: Int,
    className: String,
    formatter: (UInt8) -> String,
    filter: (UInt8) -> Bool
  ) -> String {
    var html = #"<table class="striped \#(className)" cellspacing="0">"#
    html += "<tr><th></th>"

    for index in 0..<itemsPerRow {
      html += "<th>\(String(format: "%02X", index))</th>"
    }

    html += "</tr>"

    var count = 0
    var totalCount = 0
    var needsNewLine = true

    for (index, byte) in bytes.enumerated() {
      if needsNewLine {
        html += #"<tr class="striped">"#
        html += "<th>\(String(format: "%04X", index))</th>"
        needsNewLine = false
      }

      let idString = "\(className)-\(totalCount)"
      if filter(byte) {
        html += #"<td id="\#(idString)">\#(formatter(byte))</td>"#
      } else {
        html += #"<td id="\#(idString)" class="linkedTable">&nbsp;</td>"#
      }

      count += 1
      totalCount += 1

      if count % itemsPerRow == 0 {
        needsNewLine = true
        html += "</tr>"
        count = 0
      }
    }

    if count > 0 {
      html += "</tr>"
    }

    html += "</table>"
    return html
  }

  private static func createAscii(from bytes: [UInt8]) -> String {
    var scalars = String.UnicodeScalarView()
    scalars.reserveCapacity(bytes.count)

    for byte in bytes {
      scalars.append(UnicodeScalar(Int(byte))!)
    }

    var escaped = htmlEscaped(String(scalars))
    escaped = escaped.replacingOccurrences(of: "\r\n", with: "<br/>")
    escaped = escaped.replacingOccurrences(of: "\r", with: "<br/>")
    escaped = escaped.replacingOccurrences(of: "\n", with: "<br/>")
    escaped = escaped.replacingOccurrences(of: " ", with: "&nbsp;")

    return "<code>\(escaped)</code>"
  }

  private static func isAsciiLetterOrDigit(_ byte: UInt8) -> Bool {
    switch byte {
    case 0x30...0x39, 0x41...0x5A, 0x61...0x7A:
      return true
    default:
      return false
    }
  }

  private static func loadStringResource(
    named name: String,
    extension fileExtension: String,
    bundle: Bundle
  ) throws -> String {
    guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
      throw PreviewRenderError.missingResource("\(name).\(fileExtension)")
    }

    return try String(contentsOf: url, encoding: .utf8)
  }

  private static func loadAttachments(bundle: Bundle) throws -> [PreviewAttachment] {
    try [
      PreviewAttachment(
        identifier: "style.css",
        data: loadDataResource(named: "style", extension: "css", bundle: bundle),
        contentType: UTType(filenameExtension: "css") ?? .plainText
      ),
      PreviewAttachment(
        identifier: "jquery-ui.css",
        data: loadDataResource(named: "jquery-ui", extension: "css", bundle: bundle),
        contentType: UTType(filenameExtension: "css") ?? .plainText
      ),
      PreviewAttachment(
        identifier: "jquery.js",
        data: loadDataResource(named: "jquery", extension: "js", bundle: bundle),
        contentType: UTType(filenameExtension: "js") ?? .plainText
      ),
      PreviewAttachment(
        identifier: "jquery-ui.js",
        data: loadDataResource(named: "jquery-ui", extension: "js", bundle: bundle),
        contentType: UTType(filenameExtension: "js") ?? .plainText
      )
    ]
  }

  private static func loadDataResource(
    named name: String,
    extension fileExtension: String,
    bundle: Bundle
  ) throws -> Data {
    guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
      throw PreviewRenderError.missingResource("\(name).\(fileExtension)")
    }

    return try Data(contentsOf: url)
  }

  private static func htmlEscaped(_ string: String) -> String {
    var result = ""
    result.reserveCapacity(string.count)

    for character in string {
      switch character {
      case "&":
        result += "&amp;"
      case "<":
        result += "&lt;"
      case ">":
        result += "&gt;"
      case "\"":
        result += "&quot;"
      case "'":
        result += "&#39;"
      default:
        result.append(character)
      }
    }

    return result
  }
}

struct RenderedPreview {
  let htmlData: Data
  let attachments: [PreviewAttachment]
}

struct PreviewAttachment {
  let identifier: String
  let data: Data
  let contentType: UTType
}

enum PreviewRenderError: LocalizedError {
  case missingResource(String)

  var errorDescription: String? {
    switch self {
    case .missingResource(let name):
      return "Missing preview resource: \(name)"
    }
  }
}
