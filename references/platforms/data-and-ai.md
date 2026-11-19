# Data pipelines, analytics, machine learning and LLM-powered features

Read this when the software moves or transforms data, produces numbers people make decisions with, trains or uses models, or calls a language model. The security rules for LLM features (keys, injection, untrusted output, tool approval) are in `../build/security.md` §10; this file covers building them well.

## Contents
1. Decide these first
2. Data pipelines
3. Analytics people can trust
4. Notebooks and reproducibility
5. Machine learning
6. LLM-powered features
7. Evaluating LLM features
8. Testing data code

---

## 1. Decide these first

Offer each as options (SKILL.md "Decisions"):
- **What decision or action the output drives,** and who consumes it. A report nobody acts on doesn't need a pipeline.
- **Freshness:** real time, hourly, daily, or on demand. Each step faster costs more complexity.
- **Accuracy and how it's measured,** in numbers agreed with the user (for a model: precision vs recall, and what a false positive or negative costs).
- **Data sensitivity:** personal or regulated data, where it may be stored or sent, and how long it's kept.
- **Build or use:** an existing tool (a BI dashboard, a spreadsheet, a hosted model or API) often beats a custom pipeline or model. Offer that option honestly.
- **Cost per run or per query,** especially for model APIs and cloud warehouses.

## 2. Data pipelines

- **Layers:** raw (exactly as received, kept) → cleaned (types fixed, duplicates removed, validated) → modelled (business entities and metrics). Never transform the only copy of raw data.
- **Idempotent and re-runnable:** each run for a given period produces the same output and replaces (not appends to) that period's results, so reruns and backfills are safe.
- **Partition by date** (or another natural key) so a run touches only what it needs and backfills are cheap.
- **Validate at every boundary:** schemas on input (column names, types, nullability, allowed values), row-count and freshness checks, and quarantine for bad rows instead of silently dropping them. Fail the run loudly when checks fail.
- **Deduplicate** on a business key; sources resend data.
- **Late and corrected data:** decide how far back a run re-reads, and how corrections flow through.
- **Time zones:** store UTC, bucket by the business's local day (`../concerns/localization-and-rtl.md` §3).
- **Orchestration** (Dagster, Prefect, Airflow, dbt with a scheduler) only once several steps depend on each other; a single scheduled script is fine before that (`cli-scripts-automation.md` §5).
- **SQL-first** when the data lives in a database or warehouse: transformations in version-controlled SQL (dbt or plain files), reviewed like code.
- **Tools sized to the data:** pandas or Polars and DuckDB handle many gigabytes on one machine; reach for distributed tools only when one machine truly can't cope.

## 3. Analytics people can trust

- **Define every metric once,** in one place, with its exact formula, filters and time zone ("active customer = at least one paid order in the last 30 days, Baghdad time"). Two dashboards with two definitions destroy trust.
- **Joins that multiply rows** (fan-out) silently inflate sums: check row counts before and after each join, and aggregate before joining when needed.
- **Nulls:** decide whether missing means zero, unknown or not applicable; `AVG` ignores nulls, `COUNT(column)` skips them.
- **Units and currencies** are explicit in column names or metadata (`amount_iqd`, `duration_ms`).
- **Reconcile with the source of truth:** the dashboard's revenue for a day matches the sales system's report for that day, and a test proves it on sample data.
- **Show uncertainty:** small samples, partial days and missing data are labelled, not hidden.

## 4. Notebooks and reproducibility

- **Notebooks are for exploring.** Once logic is reused or scheduled, move it into a module with tests and call it from the notebook.
- **Reproducible environments:** pinned dependencies (a lockfile), the Python version pinned, random seeds set, and the data version or snapshot recorded with each result.
- **Restart and run all** before trusting or sharing a notebook's result; out-of-order cell execution produces numbers nobody can recreate.
- **No secrets or personal data** in notebooks committed to git; outputs are cleared before committing if they contain data.

## 5. Machine learning

- **Start with a baseline:** a simple rule, the majority class, last week's value, or a linear model. A complex model that barely beats the baseline isn't worth its maintenance.
- **Split data without leakage:** time-based splits for anything that predicts the future; no information from the test period or the target in the features; group-aware splits when the same customer appears many times.
- **Metrics match the business cost:** accuracy is misleading on imbalanced data; use precision, recall, F1, calibrated probabilities or cost-weighted metrics as agreed in section 1.
- **Evaluate on slices** (regions, languages, new vs returning customers), not only on the overall average, which hides groups the model fails.
- **Track experiments:** data version, code version, parameters and metrics for every run.
- **Serving:** the same feature code in training and serving; input validation; a fallback when the model is unavailable; latency and cost measured.
- **Monitor after launch:** input drift, prediction distribution and real-world outcomes, with a retraining or rollback plan.

## 6. LLM-powered features

**Design:**
- **Decide whether an LLM is the right tool.** Deterministic code is cheaper, faster and testable; use a model where judgment over messy language or images is the point.
- **Model choice is a trade-off** between quality, latency and cost: offer it as options, and plan to re-evaluate when newer models ship. For Claude, the `claude-api` skill has current model IDs and features.
- **Call the provider from your server,** never from a client with the key inside (`../build/security.md` §10). Firebase AI Logic is the designed exception for Gemini in Firebase apps, with App Check enforced.
- **Structured outputs:** ask for JSON matching a schema (the provider's structured-output or tool-use feature where available), then validate it in code; on failure, retry once or fall back.
- **Prompts are code:** versioned in the repo, reviewed, with variables inserted in clearly delimited sections. User input goes in the user turn, never mixed into system instructions.
- **Retrieval (RAG):** chunk documents along natural boundaries, store the source with each chunk, retrieve with metadata filters (tenant, language, date), and show citations so users can check answers. Measure retrieval quality separately from answer quality.
- **Tools and agents:** each tool does one narrow thing with validated inputs and least privilege; anything that writes, sends or spends needs a human confirmation; loops have step and cost limits.

**Running it:**
- **Timeouts, retries with backoff for transient errors, and streaming** for long answers so users see progress.
- **Cost controls:** `max_tokens` on every call, prompt caching for long shared context, per-user quotas, provider spend caps, and cost logged per feature.
- **Privacy:** send only the data the task needs, check the provider's data-retention and training terms, and tell users when their content goes to a model.
- **Logging:** keep prompts, outputs, model version, latency and cost for debugging and evaluation, with personal data redacted and retention limited.
- **Fallbacks:** a clear message or a non-AI path when the provider is down or the output fails validation.
- **Language:** test in every language the product supports; quality in Kurdish or Arabic can differ a lot from English, and may need a different model or prompt.

## 7. Evaluating LLM features

LLM output can't be checked by eye on three examples. Build an evaluation set before tuning prompts:
- **A test set of real inputs** (anonymized), including hard and adversarial cases (prompt injection attempts, empty input, other languages, very long input), with the expected result or grading criteria for each.
- **Graders:** exact checks where possible (valid JSON, required fields, values in range, citations present), and model-graded or human review for quality, with the rubric written down.
- **Run it on every prompt or model change** and compare with the previous version; a change that fixes one case often breaks two others.
- **Track the numbers over time** (pass rate, cost and latency per case), and add every production failure to the set.

## 8. Testing data code

- **Unit tests** for transformations on small, hand-written frames or tables with known answers, including nulls, duplicates, empty input and boundary dates.
- **Data tests** in the pipeline: uniqueness, not-null, accepted values, relationships, freshness and row-count ranges (dbt tests, or assertions in code).
- **Integration tests** of a whole pipeline run on a fixed sample dataset, compared with a reviewed expected output.
- **Model code:** tests for feature functions and the serving path; the evaluation set (section 7) for model and prompt quality.
