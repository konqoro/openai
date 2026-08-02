const OpenAIChatCompletionsUrl* = "https://api.openai.com/v1/chat/completions"

type
  OpenAIConfig* = object
    url*: string = OpenAIChatCompletionsUrl
    apiKey*: string
