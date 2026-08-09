import std/[assertions, strutils]
import relay
import jsonx
import jsonx/parsejson
import openai/responses

const GoodResponse = """{
  "id": "resp_1",
  "object": "response",
  "created_at": 1786200000,
  "completed_at": 1786200001,
  "background": false,
  "status": "completed",
  "error": null,
  "incomplete_details": null,
  "model": "gpt-5.6-luna",
  "output": [
    {
      "id": "msg_1",
      "type": "message",
      "status": "completed",
      "role": "assistant",
      "content": [
        {
          "type": "output_text",
          "text": "{\"answer\":42}",
          "annotations": [],
          "logprobs": [],
          "future_content_field": true
        }
      ]
    },
    {
      "id": "fc_1",
      "type": "function_call",
      "status": "completed",
      "call_id": "call_1",
      "name": "lookup",
      "arguments": "{\"q\":\"nim\"}",
      "future_item_field": {}
    }
  ],
  "previous_response_id": null,
  "service_tier": "default",
  "usage": {
    "input_tokens": 20,
    "input_tokens_details": {"cached_tokens": 5, "cache_write_tokens": 2},
    "output_tokens": 9,
    "output_tokens_details": {"reasoning_tokens": 3},
    "total_tokens": 29
  },
  "metadata": {},
  "reasoning": {"effort":"low"},
  "truncation": "disabled",
  "user": null,
  "future_response_field": "ignored"
}"""

type
  Answer = object
    answer: int

  CallArgs = object
    q: string

proc sampleConfig(): OpenAIConfig =
  OpenAIConfig(apiKey: "sk-test")

block request_scalar_defaults:
  let defaults = responseCreate("gpt-5.6-luna", responseInputText("Hello"))
  doAssert defaults.parallel_tool_calls
  doAssert defaults.store
  doAssert defaults.temperature == 1.0
  doAssert defaults.top_logprobs == 0
  doAssert defaults.top_p == 1.0
  let defaultBody = toJson(defaults)
  doAssert not defaultBody.contains("\"parallel_tool_calls\":")
  doAssert not defaultBody.contains("\"store\":")
  doAssert not defaultBody.contains("\"temperature\":")
  doAssert not defaultBody.contains("\"top_logprobs\":")
  doAssert not defaultBody.contains("\"top_p\":")

  let explicit = responseCreate("gpt-5.6-luna", responseInputText("Hello"),
    background = true, parallelToolCalls = false, store = false,
    temperature = 0.0, topLogprobs = 5, topP = 0.9)
  let explicitBody = toJson(explicit)
  doAssert explicitBody.contains("\"background\":true")
  doAssert explicitBody.contains("\"parallel_tool_calls\":false")
  doAssert explicitBody.contains("\"store\":false")
  doAssert explicitBody.contains("\"temperature\":0.0")
  doAssert explicitBody.contains("\"top_logprobs\":5")
  doAssert explicitBody.contains("\"top_p\":0.9")

block simple_text_request:
  let params = responseCreate(
    model = "gpt-5.6-luna",
    input = responseInputText("Hello"),
    instructions = "Be concise.",
    maxOutputTokens = 128,
    reasoning = ResponseReasoning(effort: ResponseReasoningEffort.low),
    store = false
  )
  let body = toJson(params)
  doAssert body ==
    """{"model":"gpt-5.6-luna","input":"Hello","instructions":"Be concise.",""" &
    """"max_output_tokens":128,"reasoning":{"effort":"low"},"store":false}"""
  doAssert not body.contains("prompt_cache_retention")
  doAssert not body.contains("truncation")
  doAssert not body.contains("\"user\"")

block message_content:
  let text = responseContentText("Hello")
  doAssert text.kind == ResponseContentKind.text
  doAssert text.text == "Hello"
  doAssert toJson(text) == "\"Hello\""

  let parts = responseContentParts(@[
    responsePartText("What is shown?"),
    responsePartImageUrl("https://example.com/image.png")
  ])
  doAssert parts.kind == ResponseContentKind.parts
  doAssert parts.parts.len == 2
  doAssert toJson(parts) ==
    """[{"type":"input_text","text":"What is shown?"},""" &
    """{"type":"input_image","image_url":"https://example.com/image.png","detail":"auto"}]"""

  let decodedText = fromJson("\"decoded\"", ResponseContent)
  doAssert decodedText.kind == ResponseContentKind.text
  doAssert decodedText.text == "decoded"
  doAssertRaises JsonParsingError:
    discard fromJson("null", ResponseContent)

  let decodedParts = fromJson(
    """[{"type":"input_text","text":"decoded","future":true}]""",
    ResponseContent
  )
  doAssert decodedParts.kind == ResponseContentKind.parts
  doAssert decodedParts.parts[0].text == "decoded"
  doAssertRaises JsonParsingError:
    discard fromJson(
      """[{"type":"input_text","text":"decoded","future":true}]""",
      ResponseContent,
      unknownFields = ufReject
    )

  doAssert string(responseMessageText(ResponseInputRole.user, "Hello")) ==
    """{"role":"user","content":"Hello"}"""

block message_parts_and_tools:
  let message = responseMessageParts(ResponseInputRole.user, @[
    responsePartText("What is shown?"),
    responsePartImageUrl("https://example.com/image.png", detail = "high"),
    responsePartFileId("file_1")
  ])
  let tool = responseFunctionTool(
    "lookup",
    "Look up a value",
    RawJson("""{"type":"object","properties":{"q":{"type":"string"}}}""")
  )
  let params = responseCreate(
    "gpt-5.6-luna",
    responseInputItems(@[message]),
    tools = @[tool],
    toolChoice = ResponseToolChoiceRequired,
    text = ResponseTextConfig(format: responseFormatJsonSchema(
      "answer", RawJson("""{"type":"object"}""")
    ))
  )
  let body = toJson(params)
  doAssert body.contains("\"type\":\"input_text\"")
  doAssert body.contains("\"type\":\"input_image\"")
  doAssert body.contains("\"type\":\"input_file\"")
  doAssert body.contains("\"tool_choice\":\"required\"")
  doAssert body.contains("\"type\":\"json_schema\"")
  doAssert string(responseToolChoiceFunction("lookup")) ==
    """{"type":"function","name":"lookup"}"""

block function_outputs:
  let textOutput = responseFunctionOutput("call_1", "done")
  doAssert textOutput.call_id == "call_1"
  doAssert textOutput.output.kind == ResponseContentKind.text
  doAssert textOutput.output.text == "done"
  doAssert toJson(textOutput) ==
    """{"type":"function_call_output","call_id":"call_1","output":"done"}"""

  let jsonOutput = responseFunctionOutputJson("call_1", Answer(answer: 42))
  doAssert jsonOutput.output.text == "{\"answer\":42}"
  doAssert toJson(jsonOutput) ==
    """{"type":"function_call_output","call_id":"call_1","output":"{\"answer\":42}"}"""

  let partsOutput = responseFunctionOutputParts("call_1", @[
    responsePartText("done"),
    responsePartImageFile("file_1")
  ])
  doAssert partsOutput.output.kind == ResponseContentKind.parts
  doAssert toJson(partsOutput) ==
    """{"type":"function_call_output","call_id":"call_1","output":[""" &
    """{"type":"input_text","text":"done"},""" &
    """{"type":"input_image","file_id":"file_1","detail":"auto"}]}"""

  let decodedOutput = fromJson(
    """{"type":"function_call_output","call_id":"call_2","output":"ok","future":true}""",
    ResponseFunctionOutput
  )
  doAssert decodedOutput.call_id == "call_2"
  doAssert decodedOutput.output.text == "ok"
  doAssertRaises JsonParsingError:
    discard fromJson(
      """{"type":"function_call_output","call_id":"call_2","output":"ok","future":true}""",
      ResponseFunctionOutput,
      unknownFields = ufReject
    )

block request_and_batch:
  let cfg = sampleConfig()
  let params = responseCreate("gpt-5.6-luna", responseInputText("Hi"))
  let req = responseRequest(cfg, params, requestId = 12, timeoutMs = 3000)
  doAssert req.verb == hvPost
  doAssert req.url == OpenAIBaseUrl & "/responses"
  doAssert req.requestId == 12
  doAssert req.timeoutMs == 3000
  var batch: RequestBatch
  responseAdd(batch, cfg, params, requestId = 13)
  doAssert batch.len == 1
  doAssert batch[0].url == OpenAIBaseUrl & "/responses"

block parse_and_access:
  var parsed: ResponseCreateResult
  doAssert responseParse(GoodResponse, parsed)
  doAssert idOf(parsed) == "resp_1"
  doAssert modelOf(parsed) == "gpt-5.6-luna"
  doAssert createdAt(parsed) == 1786200000.0
  doAssert outputItems(parsed) == 2
  doAssert firstText(parsed) == "{\"answer\":42}"
  doAssert allTextParts(parsed) == @["{\"answer\":42}"]
  doAssert firstCallId(parsed) == "call_1"
  doAssert firstCallName(parsed) == "lookup"
  doAssert firstCallArgs(parsed) == "{\"q\":\"nim\"}"
  doAssert functionCalls(parsed).len == 1
  doAssert hasFunctionCalls(parsed)
  doAssert hasUsage(parsed)
  doAssert inputTokens(parsed) == 20
  doAssert cachedInputTokens(parsed) == 5
  doAssert outputTokens(parsed) == 9
  doAssert reasoningTokens(parsed) == 3
  doAssert totalTokens(parsed) == 29
  var answer: Answer
  doAssert parseFirstTextJson(parsed, answer)
  doAssert answer.answer == 42
  var args: CallArgs
  doAssert parseFirstCallArgs(parsed, args)
  doAssert args.q == "nim"

  parsed.output[0].content[0].text = """{"answer":42,"future":true}"""
  doAssert parseFirstTextJson(parsed, answer)
  doAssert not parseFirstTextJson(parsed, answer, unknownFields = ufReject)
  parsed.output[1].arguments = """{"q":"nim","future":true}"""
  doAssert parseFirstCallArgs(parsed, args)
  doAssert not parseFirstCallArgs(parsed, args, unknownFields = ufReject)

block unknown_field_policy:
  var parsed: ResponseCreateResult
  doAssert responseParse(GoodResponse, parsed)
  doAssert not responseParse(GoodResponse, parsed, unknownFields = ufReject)

block parse_failure:
  var parsed: ResponseCreateResult
  doAssert not responseParse("{bad json", parsed)

block missing_accessors:
  var parsed: ResponseCreateResult
  doAssert responseParse(
    """{"id":"r","object":"response","created_at":1,"status":"in_progress",""" &
      """"model":"m","output":[],"usage":null}""",
    parsed
  )
  doAssertRaises ValueError:
    discard firstText(parsed)
  doAssertRaises ValueError:
    discard firstCallId(parsed)
  doAssertRaises ValueError:
    discard inputTokens(parsed)
