import std/random
import relay
import openai/retry

proc main() =
  let policy = defaultRetryPolicy(
    maxAttempts = 5,
    baseDelayMs = RetryBaseDelayMs,
    maxDelayMs = RetryMaxDelayMs,
    jitterDivisor = RetryJitterDivisor
  )

  var rng = initRand(42)
  var delays: seq[int] = @[]
  for attempt in 1..policy.maxAttempts:
    delays.add(retryDelayMs(rng, attempt, policy))

  doAssert delays.len == policy.maxAttempts
  doAssert delays[0] >= backoffBaseMs(1, policy.baseDelayMs, policy.maxDelayMs)
  doAssert isRetriableStatus(Http408)
  doAssert isRetriableStatus(Http409)
  doAssert isRetriableStatus(Http425)
  doAssert isRetriableStatus(Http429)
  doAssert isRetriableStatus(Http500)
  doAssert isRetriableStatus(Http503)
  doAssert not isRetriableStatus(Http200)
  doAssert not isRetriableStatus(Http400)
  doAssert not isRetriableStatus(Http404)
  doAssert not isRetriableTransport(teNone)
  doAssert isRetriableTransport(teTimeout)
  doAssert isRetriableTransport(teNetwork)
  doAssert isRetriableTransport(teDns)
  doAssert isRetriableTransport(teTls)
  doAssert isRetriableTransport(teInternal)
  doAssert not isRetriableTransport(teCanceled)
  doAssert not isRetriableTransport(teProtocol)

  echo "retry example: attempts=", policy.maxAttempts,
    " firstDelayMs=", delays[0],
    " lastDelayMs=", delays[^1]

when isMainModule:
  main()
