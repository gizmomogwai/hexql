import Foundation

struct Template {
  let source: String

  init(_ source: String) {
    self.source = source
  }

  func render(values: [String: String]) throws -> String {
    var output = ""
    var token = ""
    var isReadingToken = false

    for character in source {
      if isReadingToken {
        if character == "»" {
          guard let replacement = values[token] else {
            throw TemplateError.missingValue(token)
          }
          output += replacement
          token.removeAll(keepingCapacity: true)
          isReadingToken = false
        } else {
          token.append(character)
        }
      } else if character == "«" {
        isReadingToken = true
        token.removeAll(keepingCapacity: true)
      } else {
        output.append(character)
      }
    }

    if isReadingToken {
      throw TemplateError.unterminatedToken(token)
    }

    return output
  }
}

enum TemplateError: LocalizedError {
  case missingValue(String)
  case unterminatedToken(String)

  var errorDescription: String? {
    switch self {
    case .missingValue(let name):
      return "Template value '\(name)' was not provided"
    case .unterminatedToken(let name):
      return "Template token '\(name)' was not terminated"
    }
  }
}
