---
type: llm
weight: 2
---

PASS if the response reports that `applyDiscount` in src/discount.js returns the discount itself instead of the discounted amount: `cents * (percent / 100)` should be `cents * (1 - percent / 100)`, so a 10% discount charges 10% of the price, and no discount (0) makes the total 0.
FAIL if the response doesn't identify this defect in src/discount.js, or says it didn't see that file.
