// Prices are stored as dollars, e.g. 19.99
export function orderTotal(items) {
  let total = 0.0;
  for (const item of items) total += parseFloat(item.price) * item.qty;
  return total.toFixed(2);
}
