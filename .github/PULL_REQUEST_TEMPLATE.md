## What

<!-- One or two sentences. Link the issue if there is one. -->

## Why / evidence

<!-- For behaviour changes: what failed, how often, where (runs, eval cases, human reviews). -->

## Contract (behaviour changes only)

- Should fix:
- Might break:
- How I checked (eval summary table, replay results, or "canary: check after N runs"):

## Checklist

- [ ] `claude plugin validate .` passes
- [ ] `pre-commit run --all-files` passes (includes the sensitive-information check)
- [ ] No credentials, personal data, internal hosts or private repository names
- [ ] Docs updated where behaviour changed
