// Totals are integers in minor units. discountPercent is 0-100.
export function cartTotal(items, discountPercent = 0) {
  const subtotal = items.reduce((sum, item) => sum + item.priceMinor * item.qty, 0);
  return subtotal - discountPercent;
}
