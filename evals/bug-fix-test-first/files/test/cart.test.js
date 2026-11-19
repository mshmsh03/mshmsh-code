import { test } from "node:test";
import assert from "node:assert/strict";
import { cartTotal } from "../src/cart.js";

test("adds up items without a discount", () => {
  assert.equal(cartTotal([{ priceMinor: 1500, qty: 2 }, { priceMinor: 250, qty: 1 }]), 3250);
});

test("an empty cart costs nothing", () => {
  assert.equal(cartTotal([]), 0);
});
