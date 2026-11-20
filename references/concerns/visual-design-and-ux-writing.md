# Visual design and UX writing

Read this before building or reshaping any screen people look at: web, mobile, desktop, POS. It gives the interface a look chosen for this product instead of the model's defaults, and words that help people use it. The platform files cover the engineering side (forms, focus, the four states, performance); right-to-left layout and Kurdish and Arabic fonts are in `localization-and-rtl.md`.

If the project already has a brand, a design system or an approved mockup, follow it. This file is for whatever those leave open.

## Contents
1. Start from the subject
2. Offer 2-3 directions, build the one picked
3. Check the plan against the defaults
4. Typography
5. Structure, the first screen and motion
6. Restraint and the quality floor
7. Check the real screen
8. UX writing

## 1. Start from the subject

- Before any styling, name three things: what the product is, who uses it, and the one job the screen must do. If the brief doesn't say, propose them and confirm in one question.
- Distinctive choices come from the subject's own world: its materials, places, vocabulary and the way its people already talk. A bakery's menu and a factory's stock screen should not look alike.
- Design with the real content from the first draft: real product names, prices, dates, and Kurdish or Arabic text. Placeholder text hides the layout problems that real text causes.

## 2. Offer 2-3 directions, build the one picked

How the product looks is the user's decision (Decisions, in SKILL.md). When the work is mostly one page or screen (a landing page, a menu site, a single dashboard), offer the directions in the first round, next to the questions, so one reply settles both; for a bigger app they come at the Design step. For a new interface or a redesign:
1. Draft 2-3 directions that truly differ. Each one is a small token plan:
   - **Colour:** 4-6 named hex values with their roles (background, surface, text, accent, error).
   - **Type:** one or two families and what each one is for.
   - **Layout:** one sentence and a small ASCII wireframe of the main screen, including how content aligns.
   - **One principle** that makes it this product's own.
2. Recommend one, for a reason tied to the subject and the audience. Keep the first round short: in chat, each direction gets its name and idea in one line, then three or four key colours, the type and the layout in a line or two. The full token plans and the wireframes go in the spec or design file, or in the question tool's preview where there is one. Offer a rendered side-by-side mockup instead of building it unasked; it's worth making when the user wants to see the looks or the choice is hard to judge from text.
3. Build only the direction picked, starting with a check that its fonts cover every letter and digit the product needs (§4). Later screens inside the agreed design don't need a new round.

## 3. Check the plan against the defaults

Before building, compare the plan with what you'd make for any similar app. A part that would come out the same for every brief is a default, not a choice: change it, and say what you changed. These looks keep turning up in AI-made interfaces. Each is fine when the brief asks for it, and a default when it doesn't:
- A warm cream background, a large serif headline and a terracotta or clay accent.
- A near-black background with one neon accent (acid green, vermilion).
- A newspaper layout: hairline rules, square corners, dense columns.
- The card kit: everything in identical rounded cards, one corner radius everywhere, the same soft grey shadow, and gradients as decoration.
- Template chrome: a small all-caps label above every heading, meta lines like `A · B · C`, labels like `WORD — fragment`, near-black (`#111`) used instead of choosing a colour, a monospace face for small labels, and `→` on every link and button.
- Numbered markers (01, 02, 03) on content that isn't a sequence.
- One word in each headline set apart in italic, bold or another colour.
- A big number with a small label and a gradient as the default first screen.

The user's own words win: when they ask for one of these looks, build it.

## 4. Typography

- One family, or two that are clearly different. Choose them for this product, not the family you'd use anywhere.
- Set a type scale with deliberate sizes, weights and spacing. A headline can carry the design itself.
- Keep body lines under about 80 characters. Serif body text gets a little more line height than sans-serif.
- Before building with the picked families, check that they cover every script and digit the product needs (`localization-and-rtl.md`). In the first round, choose from families known to cover them (`localization-and-rtl.md` lists some for Kurdish) and say coverage is checked after the pick.

## 5. Structure, the first screen and motion

- **Structure is information.** Borders, numbers, dividers and labels say something about the content, so use them only when it's true: numbered steps only for real steps.
- **The first screen** shows the most characteristic thing about the subject: the product itself, a live demo, the menu, the day's real numbers. Choose it for this product.
- **Motion:** at most one planned moment on load or reveal. Fade-up on every section and hover effects on every card read as generated. Motion that answers an action (opening, expanding, confirming) is good when it shows what changed. Timings and reduced motion: `../platforms/web.md` §5.
- **CSS:** keep selector specificity flat. Section classes and element classes fighting over padding and margins are a common mess.

## 6. Restraint and the quality floor

- **Spend boldness in one place:** one memorable element, with everything around it calm. Before finishing, remove one decoration.
- **The floor, without announcing it:** works down to phone width, visible keyboard focus, reduced motion respected, contrast that passes, and colours that sit well together.

## 7. Check the real screen

Judge the rendered screen, not the code. Screenshot it at phone and desktop widths, and in right-to-left if the product has it, compare it with the direction picked, and fix what drifted. Note what you chose in the living context file, so later screens stay consistent.

## 8. UX writing

Words are part of the design, and each one has a job.
- **The user's words, not the system's:** "Notifications", not "Webhook settings".
- **Buttons say what happens:** "Save changes", "Send invoice", not "Submit" or "OK".
- **One action keeps one name** through the whole flow: the "Publish" button leads to a "Published" message.
- **Errors say what happened and how to fix it,** plainly and without apologising: "Card declined. Try another card or call your bank."
- **Empty screens point to the next action:** "No products yet. Add your first product."
- **Sentence case, active voice, no filler.** Describe what something does instead of selling it, and match the tone to the brand and its audience.
- Every user-facing string goes through translation files from the first screen (`localization-and-rtl.md`).
