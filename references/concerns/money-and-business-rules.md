# Money, business rules, stock and audit trails

Read this when the software handles prices, currencies, payments, invoices, discounts, taxes, stock, balances or anything an owner will reconcile against real cash. These are the bugs that cost real money and trust, and AI-written code gets them wrong by default. Payment security (server-set amounts, verified webhooks) is in `../build/security.md`; this file is about getting the numbers and rules right.

## Contents
1. Representing money
2. Formatting currency (and IQD)
3. Several currencies and exchange rates
4. Rounding, discounts, taxes and invoices
5. Ledgers, balances and audit trails
6. Stock and inventory
7. Point of sale: cashiers, shifts, end-of-day
8. Taking payments
9. Business rules as code
10. Reports and exports

---

## 1. Representing money

- **Never binary floating point** (`float`, `double`, `REAL`, JS `number` arithmetic with fractions, `parseFloat`, `toFixed`) for amounts. `0.1 + 0.2` is `0.30000000000000004`, and in Dart `1.005 * 1000` is `1004.9999999999999`.
- **Use integers in minor units** (cents, fils) or **whole units when the currency has no practical subunit** (IQD), or a true decimal type:

| Language | Use |
|---|---|
| JavaScript/TypeScript | integers (or `BigInt` for very large sums), or a money library such as dinero.js |
| Python | `decimal.Decimal` (constructed from strings, never floats) or integers |
| Java/Kotlin | `BigDecimal` with an explicit `RoundingMode`, or `long` minor units |
| C# | `decimal` |
| Go | `int64` minor units, or a decimal library such as shopspring/decimal |
| Rust | integer minor units, or a decimal crate such as rust_decimal |
| Dart | `int` minor units |
| PHP | integers, or brick/money |
| Ruby | `BigDecimal`, or the money gem |
| SQL | `numeric(p, s)` / `decimal`, or `bigint` minor units; never `float`/`real`/`money` |

- **Store the currency code with every amount** (ISO 4217: `IQD`, `USD`). An amount without a currency is a bug waiting for the second currency.
- **One money module** owns arithmetic, rounding, allocation and formatting. Nothing else multiplies prices.
- **Derive totals from line items** in a pure function. Never keep a separately edited `total` that can drift from its lines.
- **Splitting an amount** (instalments, shared bills) uses an allocation function that distributes the remainder, so the parts always add up to the whole: 100 split three ways is 34 + 33 + 33, not 33.33 × 3.

## 2. Formatting currency (and IQD)

- Format with the locale APIs (`../concerns/localization-and-rtl.md` §3), created once and reused.
- **IQD has no practical subunit.** ISO 4217 lists 3 decimals, while CLDR (and so `Intl` and Dart's `intl`) uses 0, and formatters may silently round fractions.
  - Web and React Native: `new Intl.NumberFormat('ar-IQ', { style: 'currency', currency: 'IQD', maximumFractionDigits: 0 })`. `ar-IQ` and `ckb` give Arabic-Indic digits; plain `ar` gives Western digits.
  - Flutter: `NumberFormat.currency(locale: 'ar', name: 'IQD', decimalDigits: 0)`. Plain `locale: 'ar'` without `name` defaults to another currency with two decimals.
- Never mix 0- and 2-decimal amounts on one screen or receipt.
- Use tabular (fixed-width) digits for columns of amounts.

## 3. Several currencies and exchange rates

- Store each payment and price in its own currency; convert only for display and reporting.
- **Snapshot the exchange rate on each transaction** as part of the record (an integer like `iqdPerUsd`, or a decimal), so old sales never change when today's rate changes.
- Decide with the user: who sets the rate and how often, whether change can be given in the other currency, and how the end-of-day report shows each currency.
- Never sum amounts in different currencies without converting at a stated rate.

## 4. Rounding, discounts, taxes and invoices

These are **business decisions for the user,** not implementation details. Offer them as options with examples:
- **Rounding:** per line or per invoice, half-up or half-even (banker's rounding), and to what unit. The choice changes totals by small amounts that add up in reports.
- **Order of operations:** discount before or after tax; percentage discounts on the line or the whole order; whether discounts can stack; maximum discount without a manager.
- **Cash rounding** to the smallest note or coin in circulation is its own visible line on the receipt, never hidden inside the total.
- **Tax:** inclusive or exclusive prices, rates per product category, rounding rules required by local law. Check the local rules; don't invent them.
- **Invoices:**
  - Once issued, an invoice is immutable. Corrections are credit notes or new invoices referencing the original.
  - Invoice numbers follow the legal rules where they exist (often sequential, never reused); keep them separate from internal database IDs.
  - Store the seller's and buyer's details as they were at the time, not as a live link to records that change.

Write the chosen rules into the spec with worked examples, and make those examples the tests.

## 5. Ledgers, balances and audit trails

- **Append-only records for anything financial:** sales, payments, refunds, stock movements, balance changes. Corrections are new reversing entries with a reason, a user and a time, never edits or deletes.
- **Balances are derived** from the entries (or a cached total that a job can rebuild and verify), never a single field updated in place without history.
- **Double-entry** (every movement is a debit in one account and a credit in another, and they sum to zero) when money moves between accounts, wallets, customers' debts or the cash drawer. It makes errors visible.
- **Customer debts and credit** (common in shops): every purchase on credit and every repayment is an entry; the balance is their sum; statements can be printed for any date range.
- **Audit log** for sensitive actions: discounts, price overrides, voids, refunds, drawer opens, permission changes, data exports. Who, what, when, from which device, and the before and after values. This is the owner's anti-theft tool.
- **Concurrency:** balance changes are atomic (a transaction, `UPDATE ... SET balance = balance - $1 WHERE id = $2 AND balance >= $1`), never read, compute and write in application code.

## 6. Stock and inventory

- **Stock is the sum of append-only movements** (sale, return, receive, adjust, transfer, waste), not one `quantity` field synced last-write-wins, which silently erases sales.
- **Online decrements are atomic:** a database transaction or a conditional update (`... WHERE id = ? AND stock >= ?`), or an atomic increment in a document database. Never read, compute, write.
- **Offline devices can oversell:** two tills offline can both sell the last unit, and no check can stop that. Offer the user a policy:
  - allow negative stock with an "oversold" alert to the owner
  - or require online confirmation for chosen products
- **Units:** store conversions (box, strip, unit; carton, piece) as integers of a base unit.
- **Batches and expiry** (pharmacies, food): record the batch and expiry on each movement, sell first-expiring first, warn about expired and near-expiry stock at the counter.
- **Stocktakes** create adjustment movements with a reason; they never overwrite quantities.

## 7. Point of sale: cashiers, shifts, end-of-day

- **A paid sale is immutable.** Voids and refunds are new records with a reason, the user and the time.
- **The sale ID is created once, when the sale starts,** and reused on every retry, so a double tap or a network retry can't create two sales. "Complete sale" disables while processing.
- **Cashiers:** PINs salted and hashed with a slow key-derivation function, lockout after failed attempts, and permissions (void, discount, see profit, open the drawer) enforced in code and in data rules, not just by hiding buttons.
- **Shifts and the end-of-day (Z) report:** totals per payment method and currency, expected vs counted cash, the difference recorded, and the shift locked after closing.
- **Receipt numbers** are human-friendly and separate from sync IDs: a per-device prefix plus a local counter (`T2-000123`), allocated inside the sale's transaction.
- Offline operation, printing and scanners are in `offline-first-and-sync.md`.

## 8. Taking payments

- **Use the gateway's hosted payment page or SDK.** Card data never touches your server or app code.
- **The server sets the amount** from its own prices and the order's line items; the client only says what's being bought.
- **Only a server-verified callback marks an order paid:** verify the signature (or fetch the payment from the gateway's API), check the amount and currency match the order, and process each event once (dedupe by the gateway's event or transaction ID with a unique constraint).
- **Every payment call can end in "unknown"** (timeout after sending). Use idempotency keys derived from the order, and reconcile unknowns by asking the gateway.
- **Reconciliation:** a daily job or report compares your paid orders with the gateway's settlement report.
- **Refunds** go through the gateway's API and are recorded as their own entries.
- **Which gateway** is a decision for the user, driven by the country, currency and the client's bank. For clients in Iraq, that usually means a local gateway or aggregator the client banks with (for example FIB, ZainCash or FastPay), each with its own callback rules: read its current docs and test in its sandbox. Stripe and similar serve only the countries they list.
- **Test mode and live mode** use separate keys and separate environments; live keys never sit in development.

## 9. Business rules as code

- **Rules live in pure functions** (no UI, network or database), with names from the business's own words (sale, void, shift, debt, batch).
- **Table-driven tests with the owner's examples:** each row is an input and the expected result the owner agreed. Cover zero, maximum, refunds, 100% discounts, split payments and mixed currencies.
- **Decision tables** for rules with many conditions (discount eligibility, approval limits): one row per combination, so gaps are visible and each row becomes a test.
- **When people argue about a rule,** build a clickable one-file prototype of it (`../build/planning.md` §2) and let them try cases before writing the real thing.
- **Rules change:** keep configurable values (tax rates, limits, prices) in data with an effective date, not constants buried in code, and keep the history so old records still compute the same way.

## 10. Reports and exports

- **Reports compute from the source records** in the database (`SUM ... GROUP BY`), not by loading rows into application code, and group by the business's local day.
- **Totals reconcile:** the sales report, the payments report and the cash count agree, and a test proves it on sample data.
- **Accountant exports:** CSV with ASCII digits, no thousands separators, ISO dates, explicit currency columns, and UTF-8 **with a byte-order mark** so Excel opens Arabic-script text correctly.
- **Locked periods:** once a day or month is closed, its records don't change; corrections go into the current period.
