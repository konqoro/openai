import relay
import jsonx
import openai
import openai_audio_speech_schema

export openai_audio_speech_schema

const OpenAIAudioSpeechUrl* = "https://api.openai.com/v1/audio/speech"

type
  AudioSpeechCreateParams* = OpenAIAudioSpeechIn

proc speechCreate*(model, input, voice: sink string;
    responseFormat = AudioSpeechResponseFormat.wav;
    speed = 1.0): AudioSpeechCreateParams =
  AudioSpeechCreateParams(
    model: model,
    input: input,
    voice: voice,
    response_format: responseFormat,
    speed: speed
  )

proc withDefaultHeaders(cfg: OpenAIConfig;
    headers: sink HttpHeaders = emptyHttpHeaders()): HttpHeaders =
  result = headers
  result["Authorization"] = "Bearer " & cfg.apiKey
  result["Content-Type"] = "application/json"

proc speechRequest*(cfg: OpenAIConfig; params: AudioSpeechCreateParams;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  RequestSpec(
    verb: hvPost,
    url: cfg.url,
    headers: cfg.withDefaultHeaders(headers),
    body: toJson(params),
    requestId: requestId,
    timeoutMs: timeoutMs
  )

proc speechAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    params: AudioSpeechCreateParams; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  batch.addRequest(
    verb = hvPost,
    url = cfg.url,
    headers = cfg.withDefaultHeaders(headers),
    body = toJson(params),
    requestId = requestId,
    timeoutMs = timeoutMs
  )
