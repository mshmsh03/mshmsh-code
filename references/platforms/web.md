# Web: any framework, UI details, accessibility, performance

Read this when building any web UI: content sites, web apps, dashboards, admin tools. SKILL.md has the short version. For visual design quality, also use `designa-xoshaka`, `impeccable` or `unslop-ui` if installed; this file is about correctness and the small details. Right-to-left layout, Kurdish and Arabic text, digits and locale formatting are in `../concerns/localization-and-rtl.md`.

Sections 1-8 and 11-12 hold for every framework. Section 9 is React, section 10 is Next.js, and section 13 covers other frameworks and server-rendered apps.

## Contents
1. Forms and inputs
2. Focus, keyboard, semantics
3. Every async view's four states
4. Touch, layout, content details
5. Animation and motion
6. Accessibility numbers and testing
7. Core Web Vitals and how to fix each
8. Images, fonts, third-party scripts
9. React correctness (what AI code gets wrong)
10. Next.js server/client rules
11. Bundles, caching, static hosting, SEO
12. Measuring honestly
13. Other frameworks and server-rendered apps

---

## 1. Forms and inputs

- **Every control:**
  - A real `<label>`, wrapping checkboxes and radios so the text is part of the hit target. A placeholder is an example ending in `…`, never the label.
  - `name`, the right `type`, `inputmode` and `autocomplete` (`name`, `tel`, `email`, `street-address`, `one-time-code`, `current-password`, `new-password`).
  - `spellCheck={false}` and `autoCapitalize="none"` on email, username and code fields; `enterKeyHint` for the mobile Enter key.
- **Never block paste or typing.** Never disable zoom; keep input text ≥16 px so iOS doesn't zoom in.
- **Submit:** keep the button enabled until the request starts, then disable it, show a spinner and keep the label. Send an idempotency key so a double click can't create two orders.
- **Errors:**
  - Show the error next to its field, saying how to fix it.
  - Set `aria-invalid="true"` and link the message with `aria-describedby`.
  - On submit, focus the first invalid field or a focusable error summary.
  - Validate on blur or submit, not on every keystroke while the user types.
- **Other details:**
  - Enter submits single-field forms; Ctrl/⌘+Enter submits a textarea.
  - Trim values (text-expansion tools add trailing spaces).
  - Warn before leaving with unsaved changes.
  - Don't make users re-type what they already gave. Login allows paste and password managers.
- **Big forms:** use uncontrolled inputs (`defaultValue` + `FormData`, or react-hook-form) so each keystroke doesn't re-render the whole form.
- **Search boxes that aren't logins:** `autocomplete="off"` and non-credential field names, so password managers don't pop up.

## 2. Focus, keyboard, semantics

- **Focus:** one global `:focus-visible` ring (2 px outline with offset, ≥3:1 contrast). Never `outline: none` without a replacement.
- **Sticky headers** must not cover the focused element or anchor targets: set `scroll-padding-top` on `html`.
- **Modals:** use `<dialog>` opened with `.showModal()`, which gives the top layer, an inert background and Esc to close. The bare `open` attribute is not modal. Return focus to the trigger on close, and set `overscroll-behavior: contain`.
- **Page structure:**
  - A skip link to `<main id="main" tabindex="-1">`.
  - One `<h1>` and no skipped heading levels.
  - The SPA updates `<title>` on every route.
  - The current nav link gets `aria-current="page"`.
- **`<a>` navigates and `<button>` acts.** No `div onClick`, no `href="#"`, no `javascript:` links, no positive `tabindex`.
- **Complex widgets** (combobox, menu, tabs): native `<select>` or a vetted headless library (Radix, React Aria, Headless UI). Don't hand-roll ARIA.
- **Icon-only buttons** get an `aria-label`, and decorative SVGs get `aria-hidden="true"`. The accessible name contains the visible text. Actions fire on click, not on mousedown or touchstart.
- **Lists:** `list-style: none` (Tailwind's preflight) can drop list semantics in Safari; add `role="list"` where it matters.

## 3. Every async view's four states

Every screen that loads data has **loading, empty, error and success** states, designed on purpose:
- **Loading:**
  - Skeletons copy the final layout's dimensions (or they cause layout shift) and carry `aria-busy="true"`.
  - Show them only after ~150-300 ms and keep them up for at least ~300-500 ms, so they don't flicker.
  - Progress labels end with `…` ("Saving…").
- **Empty:** explain why it's empty and offer the main action ("No products yet. Add your first product").
- **Error:** say what failed, how to fix it, and offer retry. No dead ends, no raw `error.message`, no apologies.
- **Optimistic updates:** apply the change, reconcile with the server, and on failure roll back with an error or offer Undo. In TanStack Query: `cancelQueries`, snapshot, `setQueryData`, restore in `onError`, `invalidateQueries` in `onSettled`.
- **Destructive actions:** a confirm step with a specific verb ("Delete 3 items") or an Undo window, never instant.
- **Announcements:**
  - Render an empty `role="status"` / `aria-live="polite"` region at page load, then change its text. A region inserted together with its text is often not read.
  - Use `role="alert"` only for errors.
- **Error boundaries** catch render errors only, not event handlers or async code. Every fetch or mutation path needs a `catch` that changes what the user sees.

## 4. Touch, layout, content details

- **Touch:**
  - Targets ≥24×24 CSS px (WCAG AA); aim for 44-48. Enlarge small controls with padding or an invisible `::before`.
  - Use `touch-action: manipulation`.
  - Put `overscroll-behavior: contain` on sheets and drawers.
- **Drag and swipe** actions also work by tap and keyboard (e.g. move up/down buttons).
- **Hover content** can be dismissed with Esc and hovered itself. Nothing essential lives only in a tooltip, since touch has no hover.
- **Mobile viewport:**
  - Full-height sections use `100dvh`/`svh` (`h-dvh`), not `100vh`/`h-screen`, which sits under the mobile toolbar.
  - `env(safe-area-inset-*)` needs `viewport-fit=cover`.
  - No horizontal scroll at 320 px.
- **Long text:**
  - Use `truncate`, `line-clamp` or `overflow-wrap: anywhere`.
  - Flex children need `min-width: 0` or truncation silently fails.
  - Test empty, short, average and very long strings, because translations change length.
- **Numbers and typography:**
  - `font-variant-numeric: tabular-nums` (`tabular-nums`) on prices, totals, tables and timers.
  - Write `…`, not `...`, and put a non-breaking space between an amount and its unit (`25,000&nbsp;IQD`).
  - `text-wrap: balance` on headings and `pretty` on paragraphs. Keep body lines around 70-80 characters.
- **Colour:**
  - Never show status by colour alone; add an icon and text.
  - Check contrast in both light and dark themes.
- **Dark mode:**
  - `color-scheme` on `<html>`, plus a `theme-color` meta per scheme.
  - Explicit colours on native `<select>`.
  - An inline `<head>` script sets the theme before first paint (next-themes does this); put `suppressHydrationWarning` on `<html>` only.
- **Visual details:**
  - Nested corner radii are concentric (inner radius = outer radius minus padding).
  - Hover, active and focus states raise contrast.
  - Check layouts at 320, 768, 1024 and 1440 px, and with scrollbars always shown (as Windows users see them).
- **URL state:**
  - Filters, tab, category, page and any open panel live in the query string, so `?cat=drinks` shared on WhatsApp opens that section (`nuqs` helps).
  - Back/Forward restores scroll.
  - Don't break the back/forward cache with `unload` handlers.

## 5. Animation and motion

- **Respect reduced motion:**
  - A global `@media (prefers-reduced-motion: reduce)` rule.
  - Framer Motion: `<MotionConfig reducedMotion="user">`.
  - Tailwind: `motion-safe:` / `motion-reduce:`.
  - Zero the view-transition durations under reduced motion.
- **Animate only `transform` and `opacity`,** and list the properties. `transition: all` / `transition-all` is a smell.
- **Interruptible and short:** exit ~150 ms, enter ~210 ms, movement ~400 ms. Autoplaying motion longer than 5 s needs a pause control. Nothing flashes more than 3 times per second.
- **Origins and targets:** set `transform-origin` at the trigger, so a dropdown grows from its button. Animate a wrapper element, not the `<svg>` itself.
- **Restraint:** one deliberate entrance moment beats a fade-up on every section, which reads as AI-generated.
- **Media:** use `<video autoplay muted loop playsinline poster>` instead of a GIF, and stop it under reduced motion.
- **Multi-page static sites:** `@view-transition { navigation: auto; }` gives CSS-only cross-page fades.

## 6. Accessibility numbers and testing

- **Contrast (WCAG 2 AA):**
  - 4.5:1 for normal text.
  - 3:1 for large text, meaning ≥24 px regular or ≥18.66 px bold (not "18 px", as some guides say).
  - 3:1 for icons, input borders and focus rings.
- **Reflow and zoom:** content reflows at 320 px wide with no horizontal scroll and works at 200% zoom. Don't use fixed heights on text containers.
- **Images:** `alt` on every image, and `alt=""` when decorative or already named by adjacent text.
- **Consistency:** help (the WhatsApp button, the phone number) stays in the same place on every page.
- **Static checks:** `eslint-plugin-jsx-a11y` (recommended config). The basics checklist:
  - `<!doctype html>` and `<meta charset="utf-8">`
  - a viewport meta tag
  - `<html lang dir>` and a `<title>`
  - `alt` on every `<img>`
  - no `http://` URLs
- **Runtime checks:**
  - axe in the E2E tests (`@axe-core/playwright`), then Lighthouse.
  - Tab through every flow by hand, then use TalkBack or VoiceOver.
  - In DevTools' Rendering panel, emulate reduced motion, dark mode and vision deficiencies.
  - A Lighthouse score of 100 doesn't mean accessible: automated tools catch only some problems.

## 7. Core Web Vitals and how to fix each

Thresholds (good / poor) at the 75th percentile, mobile and desktop separately:

| Metric | Good | Poor |
|---|---|---|
| LCP | ≤2.5 s | >4 s |
| INP | ≤200 ms | >500 ms |
| CLS | ≤0.1 | >0.25 |

Lab metrics: TTFB 0.8/1.8 s, FCP 1.8/3 s, TBT 200/600 ms.

**LCP:**
- The LCP element (usually the hero image) is in the initial HTML, never fetched in `useEffect`.
- Make it a real `<img fetchpriority="high">`, not a CSS background, and **never lazy-load it**.
- Preload it only if the trace shows late discovery (`imagesrcset`/`imagesizes`).
- Serve HTML statically or from a CDN for a fast TTFB. Keep critical CSS small and `<head>` free of parser-blocking scripts.

**INP:**
- First find which phase dominates: input delay, processing or presentation.
- Split long tasks (>50 ms) with `await scheduler.yield()` (fallback `setTimeout(0)`), and paint feedback before the heavy work.
- Move CPU-heavy work to a Web Worker.
- Use `startTransition`/`useDeferredValue` when filtering while typing.
- Find the slow interaction with `web-vitals/attribution`.

**CLS:**
- Give images, iframes and embeds width/height or `aspect-ratio`.
- Reserve space for banners, cookie notices and toasts, or overlay them.
- Tune fallback-font metrics (`size-adjust`, `ascent-override`); `next/font` does this automatically.
- Find the *trigger* of the shift, not just the element that moved. Re-test after interactions.

**Prerendering:** Speculation Rules (`<script type="speculationrules">`, `eagerness: "moderate"`) prerender likely next pages in Chromium. Exclude logout and cart.

## 8. Images, fonts, third-party scripts

- **Images** (menus and portfolios are image-heavy):
  - Format chain: AVIF → WebP → JPEG via `<picture>`.
  - Size files to rendered width × device pixel ratio, with a correct `sizes`; a wrong `sizes` downloads huge files.
  - width/height on every `<img>` and every art-directed `<source>`.
  - `loading="lazy" decoding="async"` on everything except the LCP image.
  - Google Maps, YouTube and chat widgets sit behind a static facade or a lazy iframe.
- **Fonts:**
  - WOFF2, self-hosted, at most 2 families × 2-3 weights, or one variable font.
  - `font-display: swap` (`optional` for decorative faces).
  - Preload only the above-the-fold face, always with `crossorigin`, or it downloads twice.
  - With Google Fonts, add `&display=swap`, preconnect to `fonts.gstatic.com` with crossorigin, and never load fonts through CSS `@import`.
- **Scripts:**
  - Every script gets `async`, `defer` or `type=module`.
  - Load analytics after hydration (`next/script` `afterInteractive` or `lazyOnload`).
  - Don't add trackers without the client's approval.
  - Remove preconnects to origins that receive no requests.

## 9. React correctness (what AI code gets wrong)

- **Never define a component inside another component.** It remounts on every render: inputs lose focus on each keystroke and state resets. Lint: `react/no-unstable-nested-components`.
- **Derive, don't sync:**
  - Compute derived values during render, and reset state with a `key`.
  - `useEffect` is only for syncing with outside systems.
  - A click's side effects go in the click handler, not in a "set a flag, then react in an effect" chain.
- **Fetching in effects** needs an `AbortController` or an `ignore` flag, or a stale response overwrites a newer one (search boxes). Prefer TanStack Query or SWR.
- **`{items.length && <List/>}` prints "0".** Use `items.length > 0 ? ... : null`.
- **Keys:** `key={index}` on lists that reorder or delete attaches state to the wrong row; use stable IDs.
- **State updates:**
  - Use `setX(prev => ...)` when new state depends on old.
  - Use `useState(() => expensive())` for costly initial values.
  - Put primitive dependencies in effect arrays (`user.id`, not `user`).
  - Never mutate state: `.sort()` mutates, so use `toSorted()` or `[...a].sort()`. `toSorted()` needs Safari 16+, so set `browserslist` to the devices you actually support.
- **High-frequency values** (pointer position, scroll) go in refs, with direct style writes and passive listeners. Never read layout (`getBoundingClientRect`) during render.
- **Memoize only what profiling shows is slow** (React DevTools "highlight updates", React Scan). The React Compiler removes most manual memo.
- **Where state lives:** local → lifted → context for rarely-changing values (theme, locale, auth) → URL for shareable UI state → TanStack Query/SWR for server data → a global store only for complex client state.
- **Long lists:** beyond ~50-100 rows, virtualize (`@tanstack/react-virtual`). For long static sections like a full menu, use `content-visibility: auto` with `contain-intrinsic-size`.
- **localStorage:** a versioned key and minimal data, never tokens or personal data, and always wrapped in `try/catch` (it throws in Safari private mode or when full).
- **Composition:** replace piles of boolean props with explicit variant components or compound components sharing a context.

## 10. Next.js server/client rules

- **No waterfalls:**
  - Independent `await`s in a row should be `Promise.all`; start promises early and await them late.
  - A parent server component awaiting data blocks all its children, so split slow parts into sibling async components inside `<Suspense>`.
  - Keep SEO-critical and above-the-fold content out of Suspense.
- **`'use client'` on leaves, not on `layout` or `page` files.** Pass client components only the fields they need, because props are serialized into the HTML.
- **Every Server Action** (`'use server'` export) checks the session, checks ownership or role, and validates input itself. Middleware (renamed `proxy.ts` in Next 16) and page guards don't protect direct calls.
- **Module scope:** never keep request or user data in module-level variables in server code; it leaks between users.
- **Caching:** `React.cache()` dedupes per request, and `after()` runs logging after the response.
- **Hydration traps:**
  - Reading `window`, `localStorage`, `Date.now()` or `Math.random()` during render.
  - `toLocaleDateString()` with no explicit locale and time zone.
  - A controlled `value` without `onChange`.
  - `suppressHydrationWarning` anywhere except `<html>` and timestamps.
- **`next/image`:** `sizes` whenever you use `fill`. Mark the LCP image as high priority: the `priority` prop up to Next 15. Next 16 deprecated `priority`, so follow that version's docs (`preload` / `fetchPriority="high"`). Use `next/font` for self-hosted fonts with fallback metrics.
- **Measure production only:** `next build && next start`. Dev mode skips optimizations.

## 11. Bundles, caching, static hosting, SEO

- **Bundle budget** (gzipped starting points): initial JS ≤200-300 KB, CSS ≤50-100 KB, fonts ≤100 KB, third-party ≤200 KB, whole page ≤1.5 MB. Analyze with `@next/bundle-analyzer` or `npx vite-bundle-visualizer`.
- **Shrinking bundles:**
  - Lazy-load heavy, rarely used UI (editors, charts, maps, 3D) with `next/dynamic` or `React.lazy`, and preload on hover or focus.
  - Avoid `moment` and whole-`lodash` imports.
  - In Next.js, list icon and utility libraries in `optimizePackageImports`. Check the visualizer before rewriting imports in Vite, which usually tree-shakes named imports.
- **Caching:** hashed assets get `max-age=31536000, immutable`; HTML gets `no-cache`. Netlify `_headers`; GitHub Pages can't set headers (see `../build/shipping.md`).
- **SPA routing:** Netlify `/* /index.html 200`; GitHub Pages needs `base`/`basePath` plus a 404 fallback or hash routing.
- **Link previews and SEO:** OG tags must be in the served HTML, not set client-side (see the launch checklist in `../build/shipping.md` §7).
- **Production hygiene:** no public source maps, Brotli/gzip on, no redirect chains, no mixed content, a clean console.

## 12. Measuring honestly

- **Lab setup:** mobile first, with viewport, network and 4-6× CPU throttling set explicitly. Use incognito and a cold cache. Do at least 3 runs and report median, range and conditions. Report metric values, not just the Lighthouse score.
- **Field data:** CrUX is the p75 over 28 days, and small sites often have none; report "unavailable", not "passing". For real-user numbers, send `web-vitals` `onLCP/onINP/onCLS` via `sendBeacon`, grouped by route, with no personal data.
- **Changing things:** change one thing per measurement and revert changes whose gain is inside run-to-run noise. Guard budgets with Lighthouse CI.
- **Verdict:** report an already-fast page as fine. Don't invent work.

## 13. Other frameworks and server-rendered apps

The rules in sections 1-8 and 11-12 are about HTML, CSS, the browser and users, so they hold everywhere. Framework-specific traps:

**Vue and Nuxt:**
- Don't destructure reactive objects without `toRefs` (reactivity is lost); use `computed` for derived values instead of watchers that copy state.
- `v-html` is an XSS sink, like `dangerouslySetInnerHTML`; sanitize or avoid it.
- In Nuxt, fetch with `useFetch`/`useAsyncData` so server and client don't fetch twice, and keep secrets in server-only runtime config (`runtimeConfig`, not its `public` part).
- Server routes (`server/api/`) authenticate and check ownership themselves, like any endpoint.

**Svelte and SvelteKit:**
- Load data in `+page.server.ts` / `+layout.server.ts` when it needs secrets or the database; universal `+page.ts` code also runs in the browser.
- Form actions and `+server.ts` endpoints are public entry points: check the session and ownership in each.
- Private env vars come from `$env/static/private` or `$env/dynamic/private`; anything in `$env/*/public` ships to the browser.
- `{@html}` is an XSS sink.

**Angular:**
- Use the built-in sanitization; `bypassSecurityTrust*` calls are security review items.
- Unsubscribe from observables (the `async` pipe or `takeUntilDestroyed`), or components leak.
- Prefer signals or `OnPush` change detection for large views; check the version's docs, since the recommended patterns moved quickly between releases.

**Server-rendered apps** (Django, Rails, Laravel, ASP.NET Core, Spring MVC, Go templates, PHP):
- Keep the template engine's auto-escaping on; every "raw" or "safe" filter (`|safe`, `raw`, `{!! !!}`, `Html.Raw`, `template.HTML`) is an XSS review item.
- CSRF protection on every state-changing form (the framework's middleware, not a hand-rolled token).
- Mass assignment: allow-list the fields a form may set (Django forms, Rails strong parameters, Laravel `$fillable`, DTOs in ASP.NET and Spring).
- N+1 queries hide in templates that touch relations in a loop: `select_related`/`prefetch_related`, `includes`, `with()`, `Include()`, fetch joins.
- htmx or similar partial-page updates are fine; each partial endpoint still checks auth and ownership.

**Plain static sites:** sections 1-8 and 11 still apply. Forms need a server or a form service with spam protection; never put an API key for a mail or database service in the page.
