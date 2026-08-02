const
  OpenAIBaseUrl* = "https://api.openai.com/v1"
  OpenAIChatCompletionsUrl* = OpenAIBaseUrl & "/chat/completions"

type
  OpenAIConfig* = object
    baseUrl*: string = OpenAIBaseUrl
    url*: string = OpenAIChatCompletionsUrl
    apiKey*: string

proc isHttpSuccess*(code: int): bool {.inline.} =
  result = code div 100 == 2
