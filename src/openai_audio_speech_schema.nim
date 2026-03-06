import jsonx
import jsonx/streams

type
  AudioSpeechResponseFormat* = enum
    wav, mp3, flac, opus, pcm

  OpenAIAudioSpeechIn* = object
    model*: string
    input*: string
    voice*: string
    response_format*: AudioSpeechResponseFormat
    speed*: float

template writeJsonField(s: Stream; name: string; value: untyped) =
  if comma: streams.write(s, ",")
  else: comma = true
  escapeJson(s, name)
  streams.write(s, ":")
  writeJson(s, value)

proc writeJson*(s: Stream; x: OpenAIAudioSpeechIn) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "model", x.model)
  writeJsonField(s, "input", x.input)
  writeJsonField(s, "voice", x.voice)
  if x.response_format != AudioSpeechResponseFormat.wav:
    writeJsonField(s, "response_format", x.response_format)
  if x.speed != 1.0:
    writeJsonField(s, "speed", x.speed)
  streams.write(s, "}")
