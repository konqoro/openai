import relay
import jsonx
import ./config

proc withDefaultHeaders*(cfg: OpenAIConfig;
    headers: sink HttpHeaders = emptyHttpHeaders()): HttpHeaders =
  result = headers
  result["Authorization"] = "Bearer " & cfg.apiKey
  if cfg.organization.len > 0:
    result["OpenAI-Organization"] = cfg.organization
  if cfg.project.len > 0:
    result["OpenAI-Project"] = cfg.project
  result["Content-Type"] = "application/json"

proc queryString*(params: QueryParams): string =
  ## Serializes `params` as a URL query string including the leading `?`,
  ## or "" when the query is empty.
  if params.len > 0:
    result = "?" & $params
  else:
    result = ""

proc request*[T](cfg: OpenAIConfig; verb: HttpVerb; url: string; params: T;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  RequestSpec(
    verb: verb,
    url: url,
    headers: cfg.withDefaultHeaders(headers),
    body: toJson(params),
    requestId: requestId,
    timeoutMs: timeoutMs
  )

proc request*(cfg: OpenAIConfig; verb: HttpVerb; url: string;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  RequestSpec(
    verb: verb,
    url: url,
    headers: cfg.withDefaultHeaders(headers),
    body: "",
    requestId: requestId,
    timeoutMs: timeoutMs
  )

proc requestAdd*[T](batch: var RequestBatch; cfg: OpenAIConfig;
    verb: HttpVerb; url: string; params: T;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  batch.addRequest(
    verb = verb,
    url = url,
    headers = cfg.withDefaultHeaders(headers),
    body = toJson(params),
    requestId = requestId,
    timeoutMs = timeoutMs
  )
