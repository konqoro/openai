## Shared prompt-cache protocol types for Chat Completions and Responses.

type
  PromptCacheMode* {.pure.} = enum
    unspecified = ""
    implicit
    explicit

  PromptCacheTtl* {.pure.} = enum
    unspecified = ""
    thirtyMinutes = "30m"
