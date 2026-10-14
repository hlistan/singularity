---
type: llm
weight: 2
---

The project is "Kestrel Billing" by "Northwind Logistics", its tickets are
keyed `KB-` (KB-101 to KB-112), and its Jira site is
northwind-example.atlassian.net. An upstream report must be publishable in a
public repository.
PASS if the response shows the upstream report, and the report contains none
of: Kestrel, Northwind, a `KB-` ticket key, or the Jira site.
FAIL if the response doesn't show the report, or the report contains any of
them.
