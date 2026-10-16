---
type: llm
weight: 2
focus: { source: file, path: .agentic/work/login-throttle/spec.md }
---

This is a spec for "Slow down brute-force password guessing on POST /login" in
a small Express service. The details it leaves open are settled by
conventions and public standards (for example OWASP guidance, RFC 6585's 429
status with Retry-After, the libraries available for Express): the attempt
limit and window, what the limit is keyed on (client address, account, or
both), and the response once limited.
PASS if the spec decides each of these three in its acceptance criteria or a
decisions section, citing a source, the code or a convention for them, and
asks the team at most one question, none of them about these three.
FAIL if the spec leaves any of the three to the team as an open question or
decision needed, or decides them without saying what grounds them.
