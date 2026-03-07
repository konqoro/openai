import jsonx
import jsonx/streams

type
  AudioSpeechServiceTier* = enum
    `default`, priority

  AudioSpeechResponseFormat* = enum
    mp3, opus, flac, wav, pcm

  OpenAIAudioSpeechIn* = object
    service_tier*: AudioSpeechServiceTier
    model*: string
    input*: string
    voice*: string
    response_format*: AudioSpeechResponseFormat
    speed*: float
    extra_body*: string

template writeJsonField(s: Stream; name: string; value: untyped) =
  if comma: streams.write(s, ",")
  else: comma = true
  escapeJson(s, name)
  streams.write(s, ":")
  writeJson(s, value)

template writeJsonRawField(s: Stream; name: string; value: string) =
  if comma: streams.write(s, ",")
  else: comma = true
  escapeJson(s, name)
  streams.write(s, ":")
  streams.write(s, value)

proc writeJson*(s: Stream; x: OpenAIAudioSpeechIn) =
  var comma = false
  streams.write(s, "{")
  if x.service_tier != AudioSpeechServiceTier.`default`:
    writeJsonField(s, "service_tier", x.service_tier)
  writeJsonField(s, "model", x.model)
  writeJsonField(s, "input", x.input)
  if x.voice.len > 0:
    writeJsonField(s, "voice", x.voice)
  if x.response_format != AudioSpeechResponseFormat.wav:
    writeJsonField(s, "response_format", x.response_format)
  if x.speed != 1.0:
    writeJsonField(s, "speed", x.speed)
  if x.extra_body.len > 0:
    writeJsonRawField(s, "extra_body", x.extra_body)
  streams.write(s, "}")
