## Shared prompt-cache protocol types for Chat Completions and Responses.

import jsonx
import jsonx/streams

type
  PromptCacheMode* {.pure.} = enum
    unspecified = ""
    implicit
    explicit

  PromptCacheTtl* {.pure.} = enum
    unspecified = ""
    thirtyMinutes = "30m"

  PromptCacheOptions* = object
    mode*: PromptCacheMode
    ttl*: PromptCacheTtl

proc writeJson*(s: Stream; x: PromptCacheOptions) =
  var comma = false
  streams.write(s, "{")
  if x.mode != PromptCacheMode.unspecified:
    if comma: streams.write(s, ",")
    else: comma = true
    escapeJson(s, "mode")
    streams.write(s, ":")
    writeJson(s, x.mode)
  if x.ttl != PromptCacheTtl.unspecified:
    if comma: streams.write(s, ",")
    escapeJson(s, "ttl")
    streams.write(s, ":")
    writeJson(s, x.ttl)
  streams.write(s, "}")
