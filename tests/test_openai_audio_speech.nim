import std/strutils
import relay
import jsonx
import openai/audio_speech

proc sampleConfig(apiKey = "sk-test"): OpenAIConfig =
  OpenAIConfig(
    url: OpenAIAudioSpeechUrl,
    apiKey: apiKey
  )

proc testSpeechCreateDefaults() =
  let params = speechCreate(
    model = "hexgrad/Kokoro-82M",
    input = "hello",
    voice = "af_bella"
  )

  doAssert params.model == "hexgrad/Kokoro-82M"
  doAssert params.input == "hello"
  doAssert params.service_tier == AudioSpeechServiceTier.`default`
  doAssert params.voice == "af_bella"
  doAssert params.response_format == AudioSpeechResponseFormat.wav
  doAssert params.speed == 1.0
  doAssert string(params.extra_body).len == 0

  let json = toJson(params)
  doAssert json.contains("\"model\":\"hexgrad/Kokoro-82M\"")
  doAssert json.contains("\"input\":\"hello\"")
  doAssert json.contains("\"voice\":\"af_bella\"")
  doAssert not json.contains("\"service_tier\":")
  doAssert not json.contains("\"response_format\":")
  doAssert not json.contains("\"speed\":")
  doAssert not json.contains("\"extra_body\":")

proc testSpeechCreateOptionalVoice() =
  let params = speechCreate(
    model = "hexgrad/Kokoro-82M",
    input = "hello"
  )

  doAssert params.voice.len == 0
  doAssert not toJson(params).contains("\"voice\":")

proc testSpeechRequest() =
  let cfg = sampleConfig(apiKey = "new-token")
  var headers = emptyHttpHeaders()
  headers["Authorization"] = "Bearer old-token"
  headers["Content-Type"] = "text/plain"
  headers["X-Trace-Id"] = "trace-1"

  let req = speechRequest(
    cfg,
    speechCreate(
      model = "hexgrad/Kokoro-82M",
      input = "chunk text",
      voice = "af_bella",
      serviceTier = AudioSpeechServiceTier.priority,
      responseFormat = AudioSpeechResponseFormat.mp3,
      speed = 1.25
    ),
    requestId = 42,
    timeoutMs = 7_000,
    headers = move headers
  )

  doAssert req.verb == hvPost
  doAssert req.url == cfg.url
  doAssert req.requestId == 42
  doAssert req.timeoutMs == 7_000
  doAssert req.headers["Authorization"] == "Bearer new-token"
  doAssert req.headers["Content-Type"] == "application/json"
  doAssert req.headers["X-Trace-Id"] == "trace-1"

  let payload = fromJson(req.body, AudioSpeechCreateParams)
  doAssert payload.service_tier == AudioSpeechServiceTier.priority
  doAssert payload.model == "hexgrad/Kokoro-82M"
  doAssert payload.input == "chunk text"
  doAssert payload.voice == "af_bella"
  doAssert payload.response_format == AudioSpeechResponseFormat.mp3
  doAssert payload.speed == 1.25

proc testSpeechExtraBodyRawJson() =
  let params = speechCreate(
    model = "hexgrad/Kokoro-82M",
    input = "chunk text",
    voice = "af_bella",
    extraBody = RawJson(
      """{"seed":7,"speaker":"bella","stream":false,"tags":["demo",2]}"""
    )
  )
  let json = toJson(params)
  doAssert json.contains(
    "\"extra_body\":{\"seed\":7,\"speaker\":\"bella\",\"stream\":false,\"tags\":[\"demo\",2]}")

proc testSpeechAdd() =
  let cfg = sampleConfig()
  var batch: RequestBatch

  speechAdd(
    batch,
    cfg,
    speechCreate(
      model = "hexgrad/Kokoro-82M",
      input = "queued",
      voice = "af_bella"
    ),
    requestId = 9,
    timeoutMs = 99
  )

  doAssert batch.len == 1
  doAssert batch[0].requestId == 9
  doAssert batch[0].timeoutMs == 99
  doAssert batch[0].headers["Authorization"] == "Bearer sk-test"

when isMainModule:
  testSpeechCreateDefaults()
  testSpeechCreateOptionalVoice()
  testSpeechRequest()
  testSpeechExtraBodyRawJson()
  testSpeechAdd()
