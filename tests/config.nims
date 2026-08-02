# Local build config for tests
switch("path", "$projectdir/../src")

switch("threads", "on")
switch("mm", "atomicArc")

# libcurl
switch("passC", "-DCURL_DISABLE_TYPECHECK")
switch("passL", "-lcurl")
