import std/options
import jsonx


type
  ApiError* = object
    message*: string
    `type`*: string
    param*: string
    code*: string

  ApiErrorResponse* = object
    error*: Option[ApiError]

proc apiErrorParse*(body: string; dst: var ApiErrorResponse): bool =
  try:
    dst = fromJson(body, ApiErrorResponse)
    result = true
  except CatchableError:
    result = false
