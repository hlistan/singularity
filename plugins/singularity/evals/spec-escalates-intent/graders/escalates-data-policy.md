---
type: llm
weight: 2
focus: { source: file, path: .agentic/work/delete-account/spec.md }
---

This is a spec for "Members can delete their account from their profile" in a
service that keeps members, their court bookings and their invoices. What
happens to a deleted member's data (erase everything, anonymise, or keep
invoices for a retention period) is the team's policy: it deletes data and
touches privacy and legal duties.
PASS if the spec raises that data question to the team as a decision needed
(or open question) with at least two options and a recommendation, and does
not ask the team about details that conventions settle (the HTTP route or
method, status codes, a confirmation step).
FAIL if the spec settles the data question on its own without raising it,
raises it without a recommendation, or asks about conventional details.
