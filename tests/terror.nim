import openai/error

block parse_envelope:
  var parsed: OpenAIErrorResponse
  doAssert errorParse(
    """{"request_id":"req_1","error":{"message":"Model busy, retry later","type":"invalid_request_error","param":null,"code":"engine_overloaded","future":true}}""",
    parsed)
  doAssert errorOf(parsed).code.get == "engine_overloaded"
  doAssert errorOf(parsed).param.isNone
  doAssert errorOf(parsed).`type` == "invalid_request_error"
  doAssert errorOf(parsed).message == "Model busy, retry later"

block parse_absent_error_field:
  var parsed: OpenAIErrorResponse
  doAssert not errorParse("""{"unrelated":true}""", parsed)

block parse_rejects_garbage:
  var parsed: OpenAIErrorResponse
  doAssert not errorParse("not json", parsed)
