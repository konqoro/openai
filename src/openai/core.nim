const OpenAIChatCompletionsUrl* = "https://api.openai.com/v1/chat/completions"

type
  OpenAIConfig* = object
    url*: string = OpenAIChatCompletionsUrl
    apiKey*: string

proc isHttpSuccess*(code: int): bool {.inline.} =
  result = code div 100 == 2
