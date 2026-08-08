## JSON-mapped request types for the OpenAI Speech API.

import jsonx
import jsonx/streams

type
  SpeechVoiceKind* = enum
    named, custom

  SpeechVoice* = object
    case kind*: SpeechVoiceKind
    of named:
      name*: string
    of custom:
      id*: string

  SpeechResponseFormat* = enum
    mp3, opus, aac, flac, wav, pcm

  SpeechStreamFormat* = enum
    audio, sse

  OpenAISpeechIn* = object
    model*: string
    input*: string
    voice*: SpeechVoice
    instructions*: string
    response_format*: SpeechResponseFormat
    speed*: float
    stream_format*: SpeechStreamFormat

template writeJsonField(s: Stream; name: string; value: untyped) =
  if comma: streams.write(s, ",")
  else: comma = true
  escapeJson(s, name)
  streams.write(s, ":")
  writeJson(s, value)

proc writeJson*(s: Stream; x: SpeechVoice) =
  case x.kind
  of SpeechVoiceKind.named:
    writeJson(s, x.name)
  of SpeechVoiceKind.custom:
    streams.write(s, "{\"id\":")
    writeJson(s, x.id)
    streams.write(s, "}")

proc writeJson*(s: Stream; x: OpenAISpeechIn) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "model", x.model)
  writeJsonField(s, "input", x.input)
  writeJsonField(s, "voice", x.voice)
  if x.instructions.len > 0:
    writeJsonField(s, "instructions", x.instructions)
  if x.response_format != SpeechResponseFormat.mp3:
    writeJsonField(s, "response_format", x.response_format)
  if x.speed != 1.0:
    writeJsonField(s, "speed", x.speed)
  if x.stream_format != SpeechStreamFormat.audio:
    writeJsonField(s, "stream_format", x.stream_format)
  streams.write(s, "}")
