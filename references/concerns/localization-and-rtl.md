# Localization, right-to-left scripts, digits and time zones

Read this when the software has more than one language, any right-to-left script (Arabic, Kurdish Sorani, Persian, Hebrew, Urdu), users who type non-Latin digits, or users in more than one time zone. It's written with Kurdish and Arabic in mind because they exercise every rule; the rules hold for any language.

## Contents
1. Decide these first
2. Text and translations
3. Numbers, dates, currency and time zones
4. Digits typed by users
5. Search across spelling variants
6. Right-to-left on the web
7. Right-to-left in Flutter
8. Right-to-left in React Native and Expo
9. Right-to-left elsewhere: native apps, desktop, PDFs, printers, terminals, email
10. Testing

---

## 1. Decide these first

Agree these with the user (or their client) before the first screen, because each one touches every screen:
- **Languages and scripts** at launch and later, and which is the default.
- **Direction:** right-to-left only, left-to-right only, or both, switchable at runtime.
- **Digit style for display:** Western (0-9) or Arabic-Indic (٠-٩). Storage, APIs, exports and barcodes stay ASCII whatever is shown.
- **Currency and decimals:** for example IQD shown with 0 decimals (`../concerns/money-and-business-rules.md` §2).
- **Time zones:** where users are, and which zone reports use (for example `Asia/Baghdad`, UTC+3 with no daylight saving).
- **Calendars:** Gregorian only, or also Hijri or another calendar for display.
- **Where the locale lives:** a user setting, the URL (`/ckb/...`) for web pages, the device locale for apps. Never guess from the IP address.

## 2. Text and translations

- **UTF-8 everywhere:** source files, databases (`utf8mb4` in MySQL), HTTP headers, CSV exports, file names in uploads.
- **Externalize every user-facing string** into translation files from the first screen; retrofitting is a rewrite.
- **Whole sentences with placeholders,** never concatenated fragments: word order changes between languages. `t('items_in_cart', { count })`, not `count + ' ' + t('items')`.
- **Plurals through the library,** never `count === 1 ? a : b`: Arabic has six plural forms, and other languages have their own rules. Use ICU MessageFormat or the platform's plural support (`Intl.PluralRules`, Flutter's `intl` `plural`, Android plurals resources, iOS `.stringsdict` or String Catalogs, gettext `ngettext`).
- **Gender and grammatical agreement** may need select messages; ask a native speaker.
- **Keys describe meaning** (`checkout.pay_button`), not the English text, so fixing the English doesn't orphan translations.
- **Length changes:** translations can be 30-50% longer or much shorter. Layouts must grow, wrap or truncate gracefully; no fixed-width buttons.
- **Fonts must cover every letter** you need (Sorani adds ڕ ڵ ێ ۆ ە ڤ پ چ ژ گ to Arabic). Test with real sentences, never lorem ipsum; missing glyphs show as boxes or fall back to an ugly font.
- **Arabic script needs room:** larger line height (around 1.6-1.8 on the web), often one size step bigger than Latin, no letter-spacing (it breaks letter joining), no uppercase emphasis (there is no case).
- **A glossary** with one term per concept and its label in each language keeps translations consistent across screens (`../build/planning.md` §6).
- **Machine translation** is a draft; a native speaker reviews anything customers see, especially legal, money and error texts.

## 3. Numbers, dates, currency and time zones

- **Format with the platform's locale APIs,** never by hand: `Intl.NumberFormat` / `Intl.DateTimeFormat` in JS, `intl` in Dart, `NumberFormat`/`DateTimeFormatter` with a `Locale` in Java/Kotlin, `CultureInfo` in .NET, Babel or `locale`-aware libraries in Python, `NumberFormatter`/`IntlDateFormatter` in PHP.
- **Pass an explicit locale fallback list and options,** so server and client output match: for example `['ckb', 'ar-IQ']`, `numberingSystem: 'latn'` or `'arab'` as agreed, and `timeZone: 'Asia/Baghdad'`. `ar-IQ` and `ckb` default to Arabic-Indic digits in JS, plain `ar` to Western digits; check what your runtime does.
- **Locale data varies by runtime.** Small or old runtimes (Hermes on low-end Android, embedded ICU builds, minimal Docker images) may lack `ckb` data and silently fall back. Check real output on the target device or server.
- **Create formatters once** (module level or cached), not inside loops or render functions.
- **Time:**
  - Store instants in UTC, written by the server (`timestamptz` in Postgres); convert to the user's zone only for display.
  - A date-only value (a birthday, a due date, a business day) is not a timestamp: store it as a date, or it shifts by a day across zones.
  - Use IANA zone names (`Asia/Baghdad`), never fixed offsets, so daylight-saving rules elsewhere stay right.
  - Group reports by the business's local day, computed in the database or with a time-zone-aware library, not by the UTC date.
  - Never parse ambiguous strings (`03/04/2026`); exchange ISO 8601.
- **Sorting names** uses a locale-aware collator (`Intl.Collator(locale)`, ICU collation in the database), not code-point order.

## 4. Digits typed by users

- Keyboards for Arabic, Kurdish and Persian type Eastern Arabic digits (U+0660-0669, ٠-٩) or Persian digits (U+06F0-06F9, ۰-۹). Most parsers reject them: `Number('١٢٣')` is `NaN` in JS, `int.tryParse('١٢٣')` is null in Dart, `int('١٢٣')` works in Python but `float('١٢٫٥')` with an Arabic decimal separator does not.
- **Normalize to ASCII at the input boundary,** before parsing, validating or storing: map both digit ranges to 0-9, the Arabic decimal separator (٫, U+066B) to `.`, and drop thousands separators (٬, U+066C, and `,`).
- On the web, `type="number"` can reject these digits: use `type="text" inputmode="decimal"` (or `numeric`) and validate after normalizing.
- Phone numbers, barcodes and codes are ASCII in storage and APIs.
- Put this in one shared function with tests, and use it in every numeric input, search box and import path.

## 5. Search across spelling variants

- Arabic keyboards type ي and ك; Kurdish text uses ی and ک. Normalize both the stored text and the query: ك→ک, ي and ى→ی; handle ة/ه according to the client's spelling; strip diacritics (harakat) and tatweel (ـ).
- Store the normalized form in its own column (`search_key`) and index it; compare the normalized query with it.
- On the web, `Intl.Collator(locale, { sensitivity: 'base' })` helps for in-memory filtering.
- Full-text search engines need an analyzer configured for the language; test with real product or customer names.

## 6. Right-to-left on the web

- **Server-render** `<html lang="ckb" dir="rtl">` (`ar` for Arabic) into the HTML itself. Setting `dir` after hydration flashes and shifts the layout. Tag passages in another language with their own `lang` so screen readers switch voice.
- **Logical CSS only:**
  - `margin-inline-start/end`, `padding-inline-*`, `inset-inline-start/end`, `border-inline-*` and `text-align: start/end`.
  - In Tailwind: `ms-/me-/ps-/pe-/start-/end-`, `rounded-s/e` and the `rtl:` variant, never `ml-/mr-/pl-/pr-/left-/right-`.
  - Prefer `gap` to `space-x-*`.
- **Don't add `flex-row-reverse` "for RTL".** Flex and grid already follow `dir`, so it flips twice.
- **Things that don't flip on their own:**
  - `translateX`, keyframes, `background-position` and shadow x-offsets.
  - JS `scrollLeft`, which behaves differently in RTL.
  - Carousels: pass the library's RTL option.
  - Directional icons: mirror chevrons, arrows and back buttons (`rtl:-scale-x-100`); leave logos, play buttons and checkmarks alone.
  - Slide-in animations: invert the offset under `:dir(rtl)`.
- **Mixed direction:**
  - `dir="ltr"` on tel, email, URL and code inputs, and on displayed phone numbers.
  - `<bdi>` or `dir="auto"` around user names and other user-generated text.
  - Unicode isolates (U+2066-2069) in strings built in code.
- **Font subsetting:** one `@font-face` per script with `unicode-range`. Arabic needs at least U+0600-06FF, U+0750-077F, U+FB50-FDFF and U+FE70-FEFF. A Latin-only `unicode-range` copied from a tutorial sends Kurdish text to a fallback font.
- **Locale in the URL** (`/ckb/...`) so shared links and caches carry it. Detect the language from `Accept-Language` / `navigator.languages`, never the IP. Mark brand names with `translate="no"`.
- **Keyboard shortcuts:** with a Kurdish or Arabic layout active, `e.key` is an Arabic letter. Match on `e.code`.

## 7. Right-to-left in Flutter

**Flutter has no built-in Kurdish (`ckb`) localizations.** `kMaterialSupportedLanguages` has no `ckb` or `ku`. With `Locale('ckb')`, Material and Cupertino widgets get no localizations and the app renders **left-to-right** (the log warns "locale ckb is not supported by all of its localization delegates").
- Fix it with fallback delegates whose `isSupported` accepts `ckb` and whose `load` returns the Arabic localizations (`GlobalMaterialLocalizations.delegate.load(const Locale('ar'))`). Do the same for Cupertino, and for Widgets, which supplies the direction.
- Supply Sorani month and day names yourself if `intl` lacks them.
- Re-check after Flutter upgrades.

**Never wrap the app in `Directionality(textDirection: TextDirection.ltr)`** to fix one layout. Fix the layout.

**Directional widgets everywhere** (grep for the physical ones):

| Use | Not |
|---|---|
| `EdgeInsetsDirectional` | `EdgeInsets.only(left:/right:)`, `fromLTRB` |
| `AlignmentDirectional` | `Alignment.centerLeft` etc. |
| `PositionedDirectional` | `Positioned(left:/right:)` |
| `BorderRadiusDirectional` | `BorderRadius.only(topLeft:...)` |
| `TextAlign.start` / `.end` | `TextAlign.left` / `.right` |

- Mirror back arrows and chevrons; leave logos, media controls and checkmarks unmirrored.
- Bundle one font that covers every letter you need and set it in `ThemeData.fontFamily`; verify with a real Kurdish sentence.
- Arabic script clips in fixed-height boxes: test at 1.3x text scale.
- Phone numbers, barcodes, SKUs and amounts with units ("25,000 د.ع") inside RTL text go in an LTR island: Unicode isolates or a `Directionality(textDirection: TextDirection.ltr)` subtree. Phone and barcode inputs use `TextField(textDirection: TextDirection.ltr)`.

## 8. Right-to-left in React Native and Expo

- Recent Expo SDKs support RTL through `expo-localization`'s config (`supportsRTL`, `forcesRTL`).
- `I18nManager.forceRTL()` takes effect on the next start, so reload after it (`Updates.reloadAsync()` in Expo).
- Use `marginStart/End`, `paddingStart/End` and `start/end`, never `marginLeft` etc.
- Walk every screen with RTL forced on.
- Hermes relies on the device's locale data: check `Intl` output for your locales on a real low-end Android.

## 9. Right-to-left elsewhere

- **Native Android:** `android:supportsRtl="true"`, `start`/`end` attributes instead of `left`/`right`, `layoutDirection`-aware drawables; in Compose, `Arrangement.Start` and `PaddingValues(start = …)`.
- **Native iOS:** leading/trailing constraints, not left/right; SwiftUI follows the environment's `layoutDirection`; mirror directional images with `imageFlippedForRightToLeftLayoutDirection`.
- **Desktop:** WPF `FlowDirection="RightToLeft"`, WinForms `RightToLeft` plus `RightToLeftLayout`, Qt `setLayoutDirection`, and the web rules above for Electron and Tauri.
- **PDFs and documents:** embed a font with Arabic-script glyphs and use a library that shapes text (joins letters) and supports RTL; the built-in PDF fonts have no Arabic glyphs. Check the output with real text, because unshaped Arabic shows as separate, reversed letters.
- **Thermal receipt printers:** their code pages can't shape Arabic script or show Sorani letters; print an image of the receipt (`offline-first-and-sync.md` §7).
- **Terminals and CLIs:** most terminals don't shape or reorder Arabic script correctly. Keep CLI output in a Latin-script language, or write RTL output to files (HTML, PDF) instead.
- **Email:** `dir="rtl"` and `lang` on the root element of HTML emails; many clients ignore CSS logical properties, so test in the main clients.

## 10. Testing

- **Pseudo-localization or a long-string locale** catches hard-coded strings and layouts that can't grow.
- **Walk every screen in each direction** with real text in each language, including empty, short, average and very long strings.
- **Automated tests** run under RTL too: widget and golden tests under `Directionality(textDirection: TextDirection.rtl)` with real fonts loaded (unregistered fonts render as boxes); Playwright or Cypress with `dir="rtl"` and screenshots.
- **Unit tests** for the digit normalizer, search normalizer, formatters (per locale) and date grouping across midnight in the business's zone.
- **A native speaker** checks the shipped text, digit style and date formats before launch.
