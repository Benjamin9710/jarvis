import Foundation

struct BackendConfiguration: Equatable {
  let baseURL: URL
  let bearerToken: String
  let deviceName: String
}

struct BackendVoiceInteractionResult: Decodable, Equatable {
  let requestID: String
  let transcriptText: String
  let normalizedText: String
  let commandStatus: String
  let commandAction: String?
  let commandTarget: String?
  let summaryText: String
  let spokenText: String
  let responseAudioBase64: String?
  let responseAudioContentType: String?
  let responseAudioSampleRateHZ: Int?
  let sttProvider: String
  let ttsProvider: String
  let ttsStatus: String

  enum CodingKeys: String, CodingKey {
    case requestID = "request_id"
    case transcriptText = "transcript_text"
    case normalizedText = "normalized_text"
    case commandStatus = "command_status"
    case commandAction = "command_action"
    case commandTarget = "command_target"
    case summaryText = "summary_text"
    case spokenText = "spoken_text"
    case responseAudioBase64 = "response_audio_base64"
    case responseAudioContentType = "response_audio_content_type"
    case responseAudioSampleRateHZ = "response_audio_sample_rate_hz"
    case sttProvider = "stt_provider"
    case ttsProvider = "tts_provider"
    case ttsStatus = "tts_status"
  }
}

enum VoiceInteractionState: Equatable {
  case idle
  case inFlight
  case succeeded(BackendVoiceInteractionResult)
  case failed(String)

  var isInFlight: Bool {
    if case .inFlight = self {
      return true
    }

    return false
  }
}

enum BackendVoiceInteractionClientError: LocalizedError {
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
protocol BackendVoiceInteractionClientProtocol: AnyObject {
  func interact(
    clip: RecordedAudioClip,
    configuration: BackendConfiguration,
    clientRequestID: String
  ) async throws -> BackendVoiceInteractionResult
}

@MainActor
final class BackendTranscriptionClient: BackendVoiceInteractionClientProtocol {
  private let session: URLSession
  private let decoder = JSONDecoder()
  private static let interactionTimeoutSeconds: TimeInterval = 300

  init(session: URLSession? = nil) {
    if let session {
      self.session = session
    } else {
      let configuration = URLSessionConfiguration.default
      configuration.timeoutIntervalForRequest = Self.interactionTimeoutSeconds
      configuration.timeoutIntervalForResource = Self.interactionTimeoutSeconds
      self.session = URLSession(configuration: configuration)
    }
  }

  // swiftlint:disable function_body_length
  func interact(
    clip: RecordedAudioClip,
    configuration: BackendConfiguration,
    clientRequestID: String
  ) async throws -> BackendVoiceInteractionResult {
    guard FileManager.default.fileExists(atPath: clip.fileURL.path) else {
      throw BackendVoiceInteractionClientError.missingClip
    }

    let audioData: Data
    do {
      audioData = try Data(contentsOf: clip.fileURL)
    } catch {
      throw BackendVoiceInteractionClientError.transport(
        "Jarvis could not read the captured audio clip."
      )
    }

    var request = URLRequest(url: configuration.baseURL.appending(path: "v1/voice/interactions"))
    let boundary = "JarvisBoundary-\(UUID().uuidString)"
    request.httpMethod = "POST"
    request.timeoutInterval = Self.interactionTimeoutSeconds
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
      throw BackendVoiceInteractionClientError.transport(
        "Jarvis could not reach the backend interaction service.",
        code: nsError.code,
        domain: nsError.domain
      )
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw BackendVoiceInteractionClientError.invalidServerResponse
    }

    if (200..<300).contains(httpResponse.statusCode) {
      do {
        return try decoder.decode(BackendVoiceInteractionResult.self, from: responseData)
      } catch {
        throw BackendVoiceInteractionClientError.invalidServerResponse
      }
    }

    if let serverError = try? decoder.decode(BackendErrorResponse.self, from: responseData) {
      throw BackendVoiceInteractionClientError.server(
        serverError.message,
        statusCode: httpResponse.statusCode
      )
    }

    throw BackendVoiceInteractionClientError.server(
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

enum AppInteractionScenario: String {
  case success
  case unsupported
  case missingAudio = "missing-audio"
  case failure
  case misconfigured
}

@MainActor
final class MockBackendTranscriptionClient: BackendVoiceInteractionClientProtocol {
  private let result: BackendVoiceInteractionResult
  private let errorMessage: String?
  private let delayNanoseconds: UInt64

  private(set) var requestIDs: [String] = []
  private(set) var uploadedClipURLs: [URL] = []

  init(
    result: BackendVoiceInteractionResult = BackendVoiceInteractionResult(
      requestID: "mock-request",
      transcriptText: "Turn on the kitchen lights",
      normalizedText: "turn on the kitchen lights",
      commandStatus: "succeeded",
      commandAction: "turn_on",
      commandTarget: "kitchen",
      summaryText: "Kitchen lights turned on",
      spokenText: "Certainly. The kitchen lights are now on.",
      responseAudioBase64: Data("mock-audio".utf8).base64EncodedString(),
      responseAudioContentType: "audio/wav",
      responseAudioSampleRateHZ: 24_000,
      sttProvider: "mock-backend",
      ttsProvider: "mock-tts",
      ttsStatus: "succeeded"
    ),
    errorMessage: String? = nil,
    delayNanoseconds: UInt64 = 100_000_000
  ) {
    self.result = result
    self.errorMessage = errorMessage
    self.delayNanoseconds = delayNanoseconds
  }

  convenience init(scenario: AppInteractionScenario) {
    switch scenario {
    case .success:
      self.init()
    case .unsupported:
      self.init(
        result: BackendVoiceInteractionResult(
          requestID: "mock-request",
          transcriptText: "Open the garage door",
          normalizedText: "open the garage door",
          commandStatus: "unsupported",
          commandAction: nil,
          commandTarget: nil,
          summaryText: "Command not available",
          spokenText: "I'm afraid I can't do that just yet.",
          responseAudioBase64: Data("mock-audio".utf8).base64EncodedString(),
          responseAudioContentType: "audio/wav",
          responseAudioSampleRateHZ: 24_000,
          sttProvider: "mock-backend",
          ttsProvider: "mock-tts",
          ttsStatus: "succeeded"
        )
      )
    case .missingAudio:
      self.init(
        result: BackendVoiceInteractionResult(
          requestID: "mock-request",
          transcriptText: "Turn on the kitchen lights",
          normalizedText: "turn on the kitchen lights",
          commandStatus: "succeeded",
          commandAction: "turn_on",
          commandTarget: "kitchen",
          summaryText: "Kitchen lights turned on",
          spokenText: "Certainly. The kitchen lights are now on.",
          responseAudioBase64: nil,
          responseAudioContentType: nil,
          responseAudioSampleRateHZ: nil,
          sttProvider: "mock-backend",
          ttsProvider: "mock-tts",
          ttsStatus: "failed"
        )
      )
    case .failure:
      self.init(errorMessage: "Jarvis could not process the latest voice interaction.")
    case .misconfigured:
      self.init()
    }
  }

  func interact(
    clip: RecordedAudioClip,
    configuration: BackendConfiguration,
    clientRequestID: String
  ) async throws -> BackendVoiceInteractionResult {
    requestIDs.append(clientRequestID)
    uploadedClipURLs.append(clip.fileURL)
    _ = configuration

    if delayNanoseconds > 0 {
      try? await Task.sleep(nanoseconds: delayNanoseconds)
    }

    if let errorMessage {
      throw BackendVoiceInteractionClientError.server(errorMessage)
    }

    return BackendVoiceInteractionResult(
      requestID: clientRequestID,
      transcriptText: result.transcriptText,
      normalizedText: result.normalizedText,
      commandStatus: result.commandStatus,
      commandAction: result.commandAction,
      commandTarget: result.commandTarget,
      summaryText: result.summaryText,
      spokenText: result.spokenText,
      responseAudioBase64: result.responseAudioBase64,
      responseAudioContentType: result.responseAudioContentType,
      responseAudioSampleRateHZ: result.responseAudioSampleRateHZ,
      sttProvider: result.sttProvider,
      ttsProvider: result.ttsProvider,
      ttsStatus: result.ttsStatus
    )
  }
}
