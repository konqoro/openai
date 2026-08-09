import openai

block package_entry:
  # `import openai` exposes only the shared configuration. Import capabilities
  # explicitly, such as `openai/chat` or `openai/responses`.
  let cfg = OpenAIConfig(apiKey: "sk-test")
  doAssert cfg.apiKey == "sk-test"

  let response = ErrorResponse(error: ApiError(message: "bad request"))
  doAssert errorOf(response).message == "bad request"
