import jsonx
import jsonx/[parsejson, streams]

type
  Timestamp* = distinct int64

proc `$`*(x: Timestamp): string {.inline.} =
  $int64(x)

proc readJson*(dst: var Timestamp; p: var JsonParser) =
  var tmp: int64
  readJson(tmp, p)
  dst = Timestamp(tmp)

proc writeJson*(s: Stream; x: Timestamp) =
  writeJson(s, int64(x))
