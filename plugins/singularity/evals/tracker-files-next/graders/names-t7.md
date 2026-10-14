---
type: llm
weight: 2
---

The queue holds TODO tasks T3 (priority 2), T7 (priority 1) and T9 (no priority); T2 is already in progress and T1 is done.
PASS if the response names T7, "Fix the login redirect", as the next task.
FAIL if it names T3, T9, T2 or T1 as next, says the queue is empty, or claims to have started the task.
