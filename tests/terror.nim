import jsonx
import openai/error

block parse_envelope:
  var parsed: ApiErrorResponse
  doAssert apiErrorParse(
    """{"error":{"message":"Model busy, retry later","type":"invalid_request_error","param":null,"code":"engine_overloaded"}}""",
    parsed)
  doAssert parsed.error.isSome
  doAssert parsed.error.get.code == "engine_overloaded"
  doAssert parsed.error.get.`type` == "invalid_request_error"
  doAssert parsed.error.get.message == "Model busy, retry later"

block parse_absent_error_field:
  var parsed: ApiErrorResponse
  doAssert apiErrorParse("""{"unrelated":true}""", parsed)
  doAssert parsed.error.isNone

block parse_rejects_garbage:
  var parsed: ApiErrorResponse
  doAssert not apiErrorParse("not json", parsed)
