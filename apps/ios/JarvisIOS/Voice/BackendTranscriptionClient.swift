import Foundation

struct BackendConfiguration: Equatable {
  let baseURL: URL
  let bearerToken: String
  let deviceName: String
}

struct BackendTranscriptionResult: Decodable, Equatable {
  let requestID: String
  let transcriptText: String
  let normalizedText: String
  let language: String
  let durationMS: Int
  let provider: String
  let confidence: Double?

  enum CodingKeys: String, CodingKey {
    case requestID = "request_id"
    case transcriptText = "transcript_text"
    case normalizedText = "normalized_text"
    case language
    case durationMS = "duration_ms"
    case provider
    case confidence
  }
}

enum VoiceTranscriptionState: Equatable {
  case idle
  case inFlight
  case succeeded(BackendTranscriptionResult)
  case failed(String)

  var isInFlight: Bool {
    if case .inFlight = self {
      return true
    }

    return false
  }
}

enum BackendTranscriptionClientError: LocalizedError {
  case missingClip
  case invalidServerResponse
  case server(String, statusCode: Int? = nil)
  case transport(String, code: Int? = nil, domain: String? = nil)

  var errorDescription: String? {
    switch self {
    case .missingClip:
      return "The recorded audio clip is unavailable."
    case .invalidServerResponse:
      return "Jarvis received an unreadable response from the backend."
    case .server(let message, _):
      return message
    case .transport(let message, _, _):
      return message
    }
  }
}

private struct BackendErrorResponse: Decodable {
  let message: String
}

@MainActor
protocol BackendTranscriptionClientProtocol: AnyObject {
  func transcribe(
    clip: RecordedAudioClip,
    configuration: BackendConfiguration,
    clientRequestID: String
  ) async throws -> BackendTranscriptionResult
}

@MainActor
final class BackendTranscriptionClient: BackendTranscriptionClientProtocol {
  private let session: URLSession
  private let encoder = JSONDecoder()

  init(session: URLSession = .shared) {
    self.session = session
  }

  // swiftlint:disable function_body_length
  func transcribe(
    clip: RecordedAudioClip,
    configuration: BackendConfiguration,
    clientRequestID: String
  ) async throws -> BackendTranscriptionResult {
    guard FileManager.default.fileExists(atPath: clip.fileURL.path) else {
      throw BackendTranscriptionClientError.missingClip
    }

    let audioData: Data
    do {
      audioData = try Data(contentsOf: clip.fileURL)
    } catch {
      throw BackendTranscriptionClientError.transport(
        "Jarvis could not read the captured audio clip."
      )
    }

    var request = URLRequest(url: configuration.baseURL.appending(path: "v1/voice/transcriptions"))
    let boundary = "JarvisBoundary-\(UUID().uuidString)"
    request.httpMethod = "POST"
    request.setValue("Bearer \(configuration.bearerToken)", forHTTPHeaderField: "Authorization")
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.httpBody = makeMultipartBody(
      boundary: boundary,
      audioData: audioData,
      clip: clip,
      clientRequestID: clientRequestID,
      deviceName: configuration.deviceName
    )

    let responseData: Data
    let response: URLResponse
    do {
      (responseData, response) = try await session.data(for: request)
    } catch {
      let nsError = error as NSError
      throw BackendTranscriptionClientError.transport(
        "Jarvis could not reach the backend transcription service.",
        code: nsError.code,
        domain: nsError.domain
      )
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw BackendTranscriptionClientError.invalidServerResponse
    }

    if (200..<300).contains(httpResponse.statusCode) {
      do {
        return try encoder.decode(BackendTranscriptionResult.self, from: responseData)
      } catch {
        throw BackendTranscriptionClientError.invalidServerResponse
      }
    }

    if let serverError = try? encoder.decode(BackendErrorResponse.self, from: responseData) {
      throw BackendTranscriptionClientError.server(
        serverError.message,
        statusCode: httpResponse.statusCode
      )
    }

    throw BackendTranscriptionClientError.server(
      "Jarvis received an unexpected backend response.",
      statusCode: httpResponse.statusCode
    )
  }
  // swiftlint:enable function_body_length

  private func makeMultipartBody(
    boundary: String,
    audioData: Data,
    clip: RecordedAudioClip,
    clientRequestID: String,
    deviceName: String
  ) -> Data {
    var body = Data()
    let lineBreak = "\r\n"

    func append(_ string: String) {
      body.append(Data(string.utf8))
    }

    append("--\(boundary)\(lineBreak)")
    append("Content-Disposition: form-data; name=\"client_request_id\"\(lineBreak)\(lineBreak)")
    append("\(clientRequestID)\(lineBreak)")

    append("--\(boundary)\(lineBreak)")
    append("Content-Disposition: form-data; name=\"device_name\"\(lineBreak)\(lineBreak)")
    append("\(deviceName)\(lineBreak)")

    append("--\(boundary)\(lineBreak)")
    append(
      "Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(clip.filename)\"\(lineBreak)"
    )
    append("Content-Type: \(clip.contentType)\(lineBreak)\(lineBreak)")
    body.append(audioData)
    append(lineBreak)
    append("--\(boundary)--\(lineBreak)")

    return body
  }
}

enum AppTranscriptionScenario: String {
  case success
  case failure
  case misconfigured
}

@MainActor
final class MockBackendTranscriptionClient: BackendTranscriptionClientProtocol {
  private let result: BackendTranscriptionResult
  private let errorMessage: String?
  private let delayNanoseconds: UInt64

  private(set) var requestIDs: [String] = []
  private(set) var uploadedClipURLs: [URL] = []

  init(
    result: BackendTranscriptionResult = BackendTranscriptionResult(
      requestID: "mock-request",
      transcriptText: "Turn on the kitchen lights",
      normalizedText: "turn on the kitchen lights",
      language: "en",
      durationMS: 1000,
      provider: "mock-backend",
      confidence: nil
    ),
    errorMessage: String? = nil,
    delayNanoseconds: UInt64 = 100_000_000
  ) {
    self.result = result
    self.errorMessage = errorMessage
    self.delayNanoseconds = delayNanoseconds
  }

  convenience init(scenario: AppTranscriptionScenario) {
    switch scenario {
    case .success:
      self.init()
    case .failure:
      self.init(errorMessage: "Jarvis could not transcribe the latest upload.")
    case .misconfigured:
      self.init()
    }
  }

  func transcribe(
    clip: RecordedAudioClip,
    configuration: BackendConfiguration,
    clientRequestID: String
  ) async throws -> BackendTranscriptionResult {
    requestIDs.append(clientRequestID)
    uploadedClipURLs.append(clip.fileURL)
    _ = configuration

    if delayNanoseconds > 0 {
      try? await Task.sleep(nanoseconds: delayNanoseconds)
    }

    if let errorMessage {
      throw BackendTranscriptionClientError.server(errorMessage)
    }

    return BackendTranscriptionResult(
      requestID: clientRequestID,
      transcriptText: result.transcriptText,
      normalizedText: result.normalizedText,
      language: result.language,
      durationMS: result.durationMS,
      provider: result.provider,
      confidence: result.confidence
    )
  }
}
