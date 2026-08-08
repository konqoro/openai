import relay
import openai

block package_entry:
  # `import openai` exposes every capability and the shared config.
  let cfg = OpenAIConfig(apiKey: "sk-test")
  doAssert cfg.apiKey == "sk-test"

  let chat = chatCreate("gpt-4.1-mini", @[chatUserMessageText("hi")])
  doAssert chat.model == "gpt-4.1-mini"

  let batchParams = batchCreate("file-1", "/v1/chat/completions")
  doAssert batchParams.completion_window == "24h"

  let upload = fileUploadRequest(cfg, "input.jsonl", "batch", "{}")
  doAssert upload.verb == hvPost

  let speech = speechCreate("t", "hello", "alloy")
  doAssert speech.model == "t"

  let emb = embeddingCreate("m", "text")
  doAssert emb.input.kind == EmbeddingInputKind.text
  doAssert emb.input.text == "text"

  let response = responseCreate("m", responseInputText("hello"))
  doAssert response.model == "m"

  var parsed: ChatCreateResult
  doAssert chatParse("""{"id":"c","created":1,"model":"m","choices":[],"usage":{"prompt_tokens":0,"completion_tokens":0,"total_tokens":0}}""", parsed)
  doAssert createdAt(parsed) == 1
