# shop-cart

`cartTotal(items, discountPercent)` returns the order total in minor units (integers).
Each item is `{ priceMinor, qty }`. `discountPercent` is a percentage from 0 to 100:
10 means 10% off the subtotal. The result is rounded to the nearest minor unit.

Run the tests with `npm test`.
