import std/[assertions, options, strutils]

import jsonx
import openai/batches
import relay

let cfg = OpenAIConfig(
  baseUrl: "https://example.test/v1",
  url: "https://example.test/v1/chat/completions",
  apiKey: "secret",
)

block upload_is_batch_multipart:
  let data = "{\"custom_id\":\"a\"}\n"
  let r = uploadRequest(cfg, data)
  doAssert r.verb == hvPost
  doAssert r.url == "https://example.test/v1/files"
  doAssert r.headers["Authorization"] == "Bearer secret"
  doAssert r.headers["Content-Type"].startsWith("multipart/form-data; boundary=")
  doAssert r.body.contains("name=\"purpose\"\r\n\r\nbatch")
  doAssert r.body.contains("filename=\"batch.jsonl\"")
  doAssert r.body.contains(data)

block lifecycle_requests_are_exact:
  let create = createRequest(
    cfg,
    "file-1",
    RawJson("""{"submission":"s1"}"""),
  )
  doAssert create.url == "https://example.test/v1/batches"
  doAssert create.body.contains("\"input_file_id\":\"file-1\"")
  doAssert create.body.contains("\"endpoint\":\"/v1/chat/completions\"")
  doAssert create.body.contains("\"completion_window\":\"24h\"")
  doAssert create.body.contains("\"metadata\":{\"submission\":\"s1\"}")
  doAssert getRequest(cfg, "batch-1").url.endsWith("/batches/batch-1")
  doAssert cancelRequest(cfg, "batch-1").url.endsWith("/batches/batch-1/cancel")
  doAssert listRequest(cfg, "batch-1", 20).url.endsWith(
    "/batches?limit=20&after=batch-1",
  )
  doAssert contentRequest(cfg, "file-2").url.endsWith("/files/file-2/content")

block current_luna_batch_shape_parses:
  let raw = """{"cancelled_at":null,"cancelling_at":null,"completed_at":1785597094,"completion_window":"24h","created_at":1785596912,"endpoint":"/v1/chat/completions","error_file_id":null,"errors":null,"expired_at":null,"expires_at":1785683312,"failed_at":null,"finalizing_at":1785597076,"id":"batch-1","in_progress_at":1785596973,"input_file_id":"file-1","metadata":{"experiment":"test"},"model":"gpt-5.6-luna","object":"batch","output_file_id":"file-2","request_counts":{"completed":256,"failed":0,"total":256},"status":"completed","usage":{"input_tokens":659712,"input_tokens_details":{"cached_tokens":638352},"output_tokens":2570,"output_tokens_details":{"reasoning_tokens":360},"total_tokens":662282}}"""
  let b = parseBatch(raw)
  doAssert b.status == BatchStatus.completed
  doAssert b.output_file_id == some("file-2")
  doAssert b.model == some("gpt-5.6-luna")
  doAssert b.usage.get.input_tokens == 659712
  doAssert b.usage.get.input_tokens_details.cached_tokens == 638352

echo "all tests passed"
