## Helpers for creating OpenAI Speech API requests.

import relay
import ./[config, http]
import ./schema/audio_speech_schema

export config
export audio_speech_schema

const AudioSpeechPath = "/audio/speech"

proc voice*(name: sink string): SpeechVoice =
  ## Creates a built-in or provider-defined named voice.
  SpeechVoice(kind: SpeechVoiceKind.named, name: name)

proc customVoice*(id: sink string): SpeechVoice =
  ## Creates a custom voice reference.
  SpeechVoice(kind: SpeechVoiceKind.custom, id: id)

proc speechCreate*(model, input: sink string; voice: sink SpeechVoice;
    instructions: sink string = "";
    responseFormat = SpeechResponseFormat.mp3; speed = 1.0;
    streamFormat = SpeechStreamFormat.audio): SpeechParams =
  ## Creates parameters for `POST /audio/speech`.
  SpeechParams(
    model: model,
    input: input,
    voice: voice,
    instructions: instructions,
    response_format: responseFormat,
    speed: speed,
    stream_format: streamFormat
  )

proc speechCreate*(model, input, voice: sink string;
    instructions: sink string = "";
    responseFormat = SpeechResponseFormat.mp3; speed = 1.0;
    streamFormat = SpeechStreamFormat.audio): SpeechParams =
  ## Creates parameters using a named voice.
  speechCreate(model, input, voice(voice), instructions,
    responseFormat, speed, streamFormat)

proc speechRequest*(cfg: OpenAIConfig; params: SpeechParams;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  request(cfg, hvPost, cfg.url & AudioSpeechPath, params,
    requestId, timeoutMs, headers)

proc speechAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    params: SpeechParams; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  requestAdd(batch, cfg, hvPost, cfg.url & AudioSpeechPath, params,
    requestId, timeoutMs, headers)
