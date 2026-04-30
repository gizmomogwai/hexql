import Foundation
import OSLog
import QuickLookUI
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
  private static let logger = Logger(
    subsystem: "com.flopcode.hexql.app.preview-extension",
    category: "PreviewProvider"
  )

  override init() {
    super.init()
    Self.logger.log("HexQL Quick Look preview extension initialized")
  }

  func providePreview(
    for request: QLFilePreviewRequest,
    completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void
  ) {
    let fileURL = request.fileURL
    let bundle = Bundle(for: PreviewProvider.self)
    Self.logger.log("Preparing HexQL preview for \(fileURL.lastPathComponent, privacy: .public)")

    let reply = QLPreviewReply(
      dataOfContentType: .html,
      contentSize: CGSize(width: 870, height: 600)
    ) { reply in
      let preview = try HexPreviewRenderer.renderPreview(for: fileURL, bundle: bundle)
      reply.stringEncoding = .utf8
      reply.title = fileURL.lastPathComponent
      reply.attachments = Dictionary(
        uniqueKeysWithValues: preview.attachments.map { attachment in
          (
            attachment.identifier,
            QLPreviewReplyAttachment(data: attachment.data, contentType: attachment.contentType)
          )
        }
      )
      return preview.htmlData
    }
    reply.stringEncoding = .utf8
    reply.title = fileURL.lastPathComponent
    handler(reply, nil)
  }
}
