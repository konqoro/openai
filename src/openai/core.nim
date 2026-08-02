const OpenAIBaseUrl* = "https://api.openai.com/v1"

type
  OpenAIConfig* = object
    apiKey*: string
    url*: string = OpenAIBaseUrl
    organization*: string
    project*: string
