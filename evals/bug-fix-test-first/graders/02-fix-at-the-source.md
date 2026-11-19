---
type: llm
focus: trace
weight: 1
---

The fix changes the discount calculation in src/cart.js so that a percentage is taken off the subtotal (for example 10% off 3250 gives 2925), and the existing tests' expected values are left unchanged.
