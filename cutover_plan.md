# Cutover plan: `sp_load_order_profitability` → `fct_order_profitability`

Move scheduled ownership of order profitability from the legacy Snowflake
procedure `analytics.util.sp_load_order_profitability` to the dbt model
`fct_order_profitability`, reversibly and without a big-bang switch.

## Current state (verified)

- **dbt DAG**: 6 staging + 3 intermediate + `fct_order_profitability` (table),
  plus a `time_spine_daily` and a validated Semantic Layer.
- **Parity**: full-population `audit_helper` comparison classifies all 75,000
  orders as `identical` across every business column (only `loaded_at`, which is
  execution metadata, is excluded).
- **Tests**: grain PKs at every layer, FK relationships, `payment_state`
  accepted values, nonnegative net revenue, orphan-item monitor, and the
  membership tie-break unit test — all green under `dbt build`.
- **Prod job**: "Prod Job" (id `1132301`), env `483704`, branch `main`,
  `latest-fusion` (v2 Stable), 4 threads, target `default`, step `dbt build`.
  Schedule trigger is currently **off** (hourly cron defined but not armed);
  runs are manual/API today. Last run succeeded in ~15s.

## 1. Build + test command

Dedicated selector (fact + all ancestors + attached tests + unit test):

```
dbt build --select +fct_order_profitability
```

The existing whole-project `dbt build` step already covers this, so no job-step
change is strictly required — the selector above is for targeted CI / manual
validation. Add `--warn-error` in CI if you want test warnings to fail the run.

## 2. Job ordering & upstream dependencies

- Upstream inputs are the six `RAW.MERLINCO_APOTHECARIES` source tables. The dbt
  build must run **after** whatever loads those raw tables (EL/ingestion), the
  same precondition the procedure has today.
- Add a **source freshness** gate (`dbt source freshness`) ahead of the build if
  ingestion timing is variable, so the fact never rebuilds on stale raw data.
- `time_spine_daily` builds within the same `dbt build`; no extra ordering.
- No downstream dbt models depend on the fact yet; downstream **consumers** are
  external (BI/reporting) — see §4.

## 3. Target schema / database expectations

- The dbt model materializes as a **table** named `fct_order_profitability` in
  the prod environment's configured database/schema (env `483704` target
  `default`). **Confirm** that resolved location and whether it should equal the
  relation consumers read today (see §8 — the legacy output location must be
  verified; `analytics.mart.fct_order_profitability` does not currently exist in
  this account).
- Grants on the new relation must match what the legacy consumer relation has
  (BI role read access), applied via post-hook grants or a warehouse grant
  script.

## 4. Replace consumer relation vs. compatibility layer

Two options depending on the verified consumer relation name:

- **In-place replacement** — if the dbt model can be configured to build at the
  exact `database.schema.identifier` consumers already query, point dbt there
  (custom schema/alias/database config) and let the table replace the legacy
  output. Cleanest, but requires consumers to tolerate a full-refresh swap and
  the names to line up.
- **Compatibility layer** — if names can't match immediately, keep consumers on
  their current relation and expose the dbt model through a thin view
  (`create view <legacy_name> as select * from <dbt_relation>`). Lets consumers
  migrate on their own schedule; retire the view once all are moved.

Recommendation: **compatibility view** during the observation window, then
collapse to in-place once consumers are confirmed migrated.

## 5. Rollback path

- Do **not** drop or alter the procedure during observation. Keep
  `sp_load_order_profitability` and its schedule intact but **paused**, not
  deleted.
- Rollback = re-point consumers (or the compatibility view) back at the
  procedure's output relation and re-arm the procedure's schedule. Because the
  dbt model is a full-refresh table and the procedure is unchanged, rollback is
  a metadata/pointer change with no data migration.
- Keep the materialized `legacy_fct_order_profitability` baseline until retirement
  as a known-good reference for re-parity.

## 6. Observation period & monitoring

- Run **both** the procedure and the dbt build in parallel for an agreed window
  (recommend 1–2 weeks / ≥1 full business cycle).
- Daily automated **parity check** (the `audit_helper` analysis pattern) on the
  latest load; alert on any row classified other than `identical` (excluding
  `loaded_at`).
- Monitor: dbt job run status/duration, test results (esp. `order_id`
  uniqueness, `payment_state` accepted values, orphan-item monitor), and row
  count vs. the procedure (expect exactly matching order counts).
- Alert on any dbt test failure or parity drift.

## 7. Criteria to retire the procedure

Retire only when **all** hold:
- Parity `identical` for the full observation window with zero unexplained
  diffs.
- All downstream consumers confirmed reading the dbt relation (directly or via
  the compatibility view).
- dbt job green and on-schedule for the window, with alerting wired.
- Rollback verified at least once (dry run) and sign-off from data + consumer
  owners.

Then: disable the procedure's schedule, then drop the procedure and any orphaned
legacy output relation in a follow-up change.

## 8. Open decisions requiring human input

- **Consumer relation identity**: the exact `database.schema.table` downstream
  BI reads today. The step references `analytics.mart.fct_order_profitability`,
  but no `ANALYTICS` database exists in this account — this must be verified
  before choosing in-place vs. compatibility layer.
- **Prod target location**: confirm env `483704`'s resolved database/schema and
  whether the fact should build there or at the consumer location.
- **Schedule ownership**: the prod job's schedule trigger is off today. Who arms
  it, and at what cadence (the legacy proc's cadence)? What orchestrates the
  procedure now (Snowflake TASK / external scheduler) that must be paused?
- **Permissions/grants**: which roles need read on the new relation, and who
  owns applying those grants.
- **Naming**: whether to rename the dbt relation to match the legacy consumer
  name or migrate consumers to `fct_order_profitability`.
