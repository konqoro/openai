import relay
import jsonx
import ./[core, http]
import ./schema/audio_speech_schema

export core
export audio_speech_schema

const AudioSpeechPath = "/audio/speech"

type
  AudioSpeechCreateParams* = OpenAIAudioSpeechIn

proc speechCreate*(model, input: sink string; voice = "";
    serviceTier = AudioSpeechServiceTier.`default`;
    responseFormat = AudioSpeechResponseFormat.wav;
    speed = 1.0;
    extraBody: sink RawJson = RawJson("")):
    AudioSpeechCreateParams =
  AudioSpeechCreateParams(
    service_tier: serviceTier,
    model: model,
    input: input,
    voice: voice,
    response_format: responseFormat,
    speed: speed,
    extra_body: extraBody
  )

proc speechRequest*(cfg: OpenAIConfig; params: AudioSpeechCreateParams;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  request(cfg, hvPost, cfg.url & AudioSpeechPath, params,
    requestId, timeoutMs, headers)

proc speechAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    params: AudioSpeechCreateParams; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  requestAdd(batch, cfg, hvPost, cfg.url & AudioSpeechPath, params,
    requestId, timeoutMs, headers)
