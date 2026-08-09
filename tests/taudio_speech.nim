import std/strutils
import relay
import jsonx
import openai/audio_speech

proc sampleConfig(apiKey = "sk-test"): OpenAIConfig =
  OpenAIConfig(url: OpenAIBaseUrl, apiKey: apiKey)

proc testSpeechCreateDefaults() =
  let params = speechCreate("hexgrad/Kokoro-82M", "hello", "af_bella")

  doAssert params.model == "hexgrad/Kokoro-82M"
  doAssert params.input == "hello"
  doAssert params.voice.kind == SpeechVoiceKind.named
  doAssert params.voice.name == "af_bella"
  doAssert params.response_format == SpeechResponseFormat.mp3
  doAssert params.speed == 1.0
  doAssert params.stream_format == SpeechStreamFormat.audio

  let body = toJson(params)
  doAssert body.contains("\"model\":\"hexgrad/Kokoro-82M\"")
  doAssert body.contains("\"input\":\"hello\"")
  doAssert body.contains("\"voice\":\"af_bella\"")
  doAssert not body.contains("\"response_format\":")
  doAssert not body.contains("\"speed\":")
  doAssert not body.contains("\"stream_format\":")

proc testSpeechOptionalFields() =
  let params = speechCreate(
    model = "hexgrad/Kokoro-82M",
    input = "hello",
    voice = "af_bella",
    instructions = "Speak warmly",
    responseFormat = SpeechResponseFormat.aac,
    speed = 1.25,
    streamFormat = SpeechStreamFormat.sse
  )

  let body = toJson(params)
  doAssert body.contains("\"instructions\":\"Speak warmly\"")
  doAssert body.contains("\"response_format\":\"aac\"")
  doAssert body.contains("\"speed\":1.25")
  doAssert body.contains("\"stream_format\":\"sse\"")

  let custom = speechCreate("gpt-4o-mini-tts", "hello",
    customVoice("voice_1234"))
  doAssert toJson(custom).contains("\"voice\":{\"id\":\"voice_1234\"}")

proc testSpeechRequest() =
  let cfg = sampleConfig(apiKey = "new-token")
  var headers = emptyHttpHeaders()
  headers["Authorization"] = "Bearer old-token"
  headers["Content-Type"] = "text/plain"
  headers["X-Trace-Id"] = "trace-1"

  let req = speechRequest(
    cfg,
    speechCreate("hexgrad/Kokoro-82M", "chunk text", "af_bella",
      responseFormat = SpeechResponseFormat.wav, speed = 1.25),
    requestId = 42,
    timeoutMs = 7_000,
    headers = move headers
  )

  doAssert req.verb == hvPost
  doAssert req.url == cfg.url & "/audio/speech"
  doAssert req.requestId == 42
  doAssert req.timeoutMs == 7_000
  doAssert req.headers["Authorization"] == "Bearer new-token"
  doAssert req.headers["Content-Type"] == "application/json"
  doAssert req.headers["X-Trace-Id"] == "trace-1"
  doAssert req.body.contains("\"response_format\":\"wav\"")

proc testSpeechAdd() =
  let cfg = sampleConfig()
  var batch: RequestBatch

  speechAdd(batch, cfg, speechCreate("m", "queued", "alloy"),
    requestId = 9, timeoutMs = 99)

  doAssert batch.len == 1
  doAssert batch[0].requestId == 9
  doAssert batch[0].timeoutMs == 99
  doAssert batch[0].headers["Authorization"] == "Bearer sk-test"

when isMainModule:
  testSpeechCreateDefaults()
  testSpeechOptionalFields()
  testSpeechRequest()
  testSpeechAdd()
