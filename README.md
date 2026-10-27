# cdc_modelling

dbt project that models paid marketing data (currently Facebook Ads) on Databricks, with CI/CD on GitHub Actions.

- **dbt project:** [`cdc_marketing/`](cdc_marketing/)
- **Warehouse:** Databricks (Unity Catalog)
- **Tooling:** [uv](https://docs.astral.sh/uv/) for Python deps, sqlfluff for SQL linting, Elementary for data observability
- **Code owner:** [@victoredo](https://github.com/victoredo) (see [`.github/CODEOWNERS`](.github/CODEOWNERS))

---

## Contents

- [Repository layout](#repository-layout)
- [What the project contains](#what-the-project-contains)
- [Environments](#environments)
- [Local development](#local-development)
- [Development workflow](#development-workflow)
- [CI/CD](#cicd)
  - [Continuous Integration (pull requests)](#continuous-integration-pull-requests)
  - [Deploy to Staging](#deploy-to-staging)
  - [Deploy to Production](#deploy-to-production)
  - [How the build decides what to run](#how-the-build-decides-what-to-run)
  - [Artifacts: manifest, docs and Elementary report](#artifacts-manifest-docs-and-elementary-report)
  - [Secrets and settings](#secrets-and-settings)
- [Conventions](#conventions)

---

## Repository layout

```
.
├── .github/
│   ├── CODEOWNERS
│   ├── actions/
│   │   ├── dbt_ci_cd/          # the dbt build pipeline (state download, build, docs, artifacts)
│   │   ├── elementary/         # generate + upload the Elementary report
│   │   ├── export_dev_schema/  # derive the PR schema name (PR_<BRANCH>)
│   │   └── setup_uv/           # install Python, uv and the project's dependencies (cached)
│   └── workflows/
│       ├── ci.yml                  # pull requests: lint + slim dbt build
│       ├── deploy_staging.yml      # PR labelled `deploy-to-staging`
│       ├── deploy_production.yml   # push to main, daily schedule, manual trigger
│       └── _dbt.yml                # reusable dbt job called by the three workflows above
├── .pre-commit-config.yaml
└── cdc_marketing/              # the dbt project
    ├── dbt_project.yml
    ├── profiles.yml            # targets: dev, ci, staging, production (+ elementary profile)
    ├── packages.yml
    ├── vars.yml
    ├── pyproject.toml / uv.lock
    ├── .sqlfluff / .sqlfluffignore
    ├── macros/
    ├── models/
    │   ├── staging/
    │   ├── intermediate/
    │   └── marts/
    ├── seeds/
    ├── snapshots/
    └── tests/
```

---

## What the project contains

### Sources

Defined in [`models/staging/facebook/sources.yml`](cdc_marketing/models/staging/facebook/sources.yml) as `facebook_ads`, read from `bronze_production.cdc_staging`. Source freshness warns after 2 days.

| Source table | Physical table | Event time |
|---|---|---|
| `campaigns` | `new_campaign_de_randomized` | `campaign_updated_at` |
| `adgroups` | `new_adgroup_de_randomized` | `ad_group_updated_at` |
| `ads` | `new_ads_de_randomized` | `ad_updated_at` |
| `accounts` | `new_acccount_de_randomized` | `account_updated_at` |
| `ads_stats` | `ads_stats` | `ad_date` |

### Models

| Layer | Model | Materialization | Description |
|---|---|---|---|
| staging | `stg_facebook_ads_account_history` | view | Facebook ad accounts |
| staging | `stg_facebook_ads_campaign_history` | view | Facebook campaign history |
| staging | `stg_facebook_ads_ad_set_history` | view | Facebook ad set (ad group) history |
| staging | `stg_facebook_ads_ad_history` | view | Facebook ads |
| staging | `stg_facebook_ads_basic_all_levels` | view | Daily spend, impressions and clicks at ad level |
| intermediate | `int_facebook_ads_details` | table | Ads joined with ad set, campaign and account details |
| marts | `dim_facebook_ads_details` | table | Ad dimension |
| marts | `fct_facebook_ads_stats_daily` | incremental (microbatch) | Daily ad stats fact |

Lineage:

```
sources ─► stg_facebook_ads_*_history ─► int_facebook_ads_details ─► dim_facebook_ads_details
        └► stg_facebook_ads_basic_all_levels ──────────────────────► fct_facebook_ads_stats_daily
```

### Macros

| Macro | Purpose |
|---|---|
| `generate_database_name` / `generate_schema_name` | Use the custom catalog/schema from `dbt_project.yml` only on `staging` and `production`. On `dev` and `ci` everything lands in the target's own catalog and schema. |
| `add_rows_limit(number_rows=1000)` | Adds `LIMIT n` on the `dev` and `ci` targets when the `dev_limit` var is `true` (set in `vars.yml`), to keep dev/CI runs fast. |
| `drop_schemas(dry_run, schema_startswith)` | Drops the PR schema. CI calls it before each build so every run starts clean. Refuses to run unless the schema starts with the given prefix. |
| `check_null(column)` | Returns `'2'` when the column is null. Not used by any model yet. |

### Tests

- Generic tests in the model `.yml` files (plus `dbt_utils` and `dbt_expectations`).
- Singular tests in [`tests/singular/`](cdc_marketing/tests/singular/).

### Packages

`dbt-labs/dbt_utils`, `metaplane/dbt_expectations`, `elementary-data/elementary` (see [`packages.yml`](cdc_marketing/packages.yml)). `dbt_project_evaluator` is configured in `dbt_project.yml` and only enabled in CI when `ENABLE_DBT_PROJECT_EVALUATOR=true`.

---

## Environments

The target is chosen with the `DBT_TARGET` env var (default `dev`). All targets use the same Databricks workspace and SQL warehouse.

| Target | Used by | Auth | Where models are written |
|---|---|---|---|
| `dev` | You, locally | Personal access token | `$DEV_CATALOG.$DEV_SCHEMA` (everything in one schema) |
| `ci` | CI on pull requests | Service principal (OAuth) | `ci_development.PR_<BRANCH_NAME>` (everything in one schema) |
| `staging` | Deploy to Staging | Service principal (OAuth) | Per layer, see below |
| `production` | Deploy to Production | Service principal (OAuth) | Per layer, see below |

On `staging` and `production`, models are routed by layer:

| Layer | Staging | Production |
|---|---|---|
| `models/staging` | `silver_staging.staging` | `silver_production.staging` |
| `models/intermediate` | `silver_staging.preparation` | `silver_production.preparation` |
| `models/marts` | `gold_staging.marketing_spend` | `gold_production.marketing_spend` |
| Elementary models | `silver_staging.elementary` | `silver_production.elementary` |
| Anything else (e.g. seeds) | `gold_staging.analytics` | `gold_production.analytics` |

---

## Local development

### 1. Prerequisites

- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- A Databricks personal access token for the workspace
- Python 3.11 – 3.13 (uv can install it for you)

### 2. Install dependencies

```bash
cd cdc_marketing
uv sync
```

This creates `cdc_marketing/.venv` with dbt, Elementary, dbt-colibri, sqlfluff and diff-cover. Prefix commands with `uv run` (or activate the venv).

### 3. Set environment variables

The `dev` target reads these. Put them in a local `.env` (git-ignored) and `source` it, or export them in your shell:

```bash
export DATABRICKS_PAT_TOKEN=<your-databricks-pat>
export DEV_CATALOG=<catalog you can write to>
export DEV_SCHEMA=dbt_<your_name>
```

> Never commit tokens. `.env` and `.env.template` are in `.gitignore`.

### 4. Run dbt

Run from inside `cdc_marketing/` so dbt picks up `profiles.yml`:

```bash
uv run dbt deps
uv run dbt debug
uv run dbt build
```

Useful variations:

```bash
uv run dbt build --select stg_facebook_ads_ad_history+   # a model and everything downstream
uv run dbt build --select staging.facebook                # everything in a folder
uv run dbt docs generate && uv run dbt docs serve
```

#### Column-level lineage (docglow)

[docglow](https://github.com/docglow/docglow) builds a docs site with column-level lineage from `target/manifest.json` (+ `catalog.json`). It runs offline with sqlglot, so no warehouse connection or dbt platform account is needed. It runs through `uvx` in its own environment rather than the project venv, because docglow 0.9.2 needs `sqlglot<30` while dbt-colibri needs `sqlglot` 30.x. Health-score settings (complexity thresholds, weights, naming rules) live in [`docglow.yml`](cdc_marketing/docglow.yml). Run `dbt docs generate` first so the manifest has compiled SQL:

```bash
uv run dbt docs generate
uvx docglow@0.9.2 generate --project-dir . --output-dir target/docglow --exclude "models/edr/*"
uvx docglow@0.9.2 serve --dir target/docglow              # then open Lineage, pick a model, expand its columns
```

Columns docglow couldn't trace are listed in `target/docglow/.docglow-column-lineage-failures.log` (hard-coded literals such as `'Paid Social' AS channel_name` show up there by design).

#### Column-level lineage (dbt-colibri)

[dbt-colibri](https://github.com/b-ned/dbt-colibri) is a second column-lineage report, also offline (sqlglot). Unlike docglow it reads each model's columns from `catalog.json`, so the models must be **built** before `dbt docs generate`, otherwise only source → staging lineage appears.

```bash
uv run dbt build
uv run dbt docs generate
DO_NOT_TRACK=1 DBT_COLIBRI_NO_VERSION_CHECK=1 uv run colibri generate --output-dir target/colibri --disable-telemetry
python3 -m http.server 8080 -d target/colibri    # then open http://localhost:8080
```

Always pass `--disable-telemetry`: the generated report otherwise sends anonymous usage events (adapter type, node count) to PostHog from every viewer's browser.

### 5. Lint SQL

```bash
uv run sqlfluff lint models
uv run sqlfluff fix models
```

To run the same check as CI (only lines changed against `main`), from the repo root:

```bash
uv run --project cdc_marketing diff-quality --violations sqlfluff --compare-branch=origin/main --fail-under=100
```

Optionally install the pre-commit hooks (trailing whitespace, end of file, YAML check, sqlfluff):

```bash
uvx pre-commit install
```

---

## Development workflow

1. Branch off `main` and make your changes.
2. Run and test locally against your `dev` schema.
3. Push and open a PR into `main`. **CI** runs automatically (lint, then a slim dbt build in `ci_development.PR_<BRANCH>`).
4. Optional: add the **`deploy-to-staging`** label to deploy the PR to the staging catalogs.
5. Get a review from the code owner and merge. **Deploy to Production** runs on the merge to `main`.

---

## CI/CD

All three workflows call the same reusable job, [`_dbt.yml`](.github/workflows/_dbt.yml). It checks out the repo, installs the `cdc_marketing` uv project, and runs the [`dbt_ci_cd`](.github/actions/dbt_ci_cd/action.yml) composite action with the right `DBT_TARGET`.

| Workflow | Trigger | Target | What it builds |
|---|---|---|---|
| [Continuous Integration](.github/workflows/ci.yml) | PR opened, updated or reopened | `ci` | Lint, then changed models + 1 level downstream |
| [Deploy to Staging](.github/workflows/deploy_staging.yml) | PR into `main` labelled `deploy-to-staging` | `staging` | Changed models + everything downstream |
| [Deploy to Production](.github/workflows/deploy_production.yml) | Push to `main` | `production` | Changed models + everything downstream |
| [Deploy to Production](.github/workflows/deploy_production.yml) | Daily at 10:00 UTC, or manual run | `production` | Whole project (`dbt build`) |

### Continuous Integration (pull requests)

Triggered on `pull_request` (`opened`, `synchronize`, `reopened`). A new push to the PR cancels the previous run.

1. **Lint:** `diff-quality` runs sqlfluff on the **lines you changed** compared with `main` and fails below 100%. Unchanged lines in old files are not checked.
2. **Build** (only if lint passes), target `ci`:
   1. Download the latest production `manifest.json` (see [Artifacts](#artifacts-manifest-docs-and-elementary-report)).
   2. Set `DEV_SCHEMA=PR_<BRANCH_NAME>` (upper-cased, `/ - .` replaced by `_`).
   3. `dbt debug` and `dbt deps`.
   4. Drop the PR schema so the run starts clean.
   5. Run `dbt_project_evaluator` if anything changed.
   6. An `--empty` run of changed models + 1 level downstream, to catch compile and schema errors quickly.
   7. `dbt build --select state:modified+1 --defer --state target_prod --indirect-selection=buildable --fail-fast`.

`--defer` means any upstream model that isn't rebuilt is read from **production**, so CI only builds what you changed.

### Deploy to Staging

Triggered when a PR into `main` is **labelled `deploy-to-staging`**. It runs once per labelling: after pushing new commits, remove and re-add the label to redeploy.

1. Download the production `manifest.json`.
2. `dbt build --select state:modified+ --defer --state target_prod --full-refresh`: everything the PR changed compared with production, plus everything downstream, written to the **staging** catalogs.
3. Generate dbt docs, the docglow site and the dbt-colibri report, then upload them as the `dbt-docs-staging`, `docglow-staging` and `colibri-staging` artifacts.
4. Run Elementary against the `staging` profile and upload `elementary-report-staging`.

Staging never uploads a manifest, so it can't change what CI and production compare against.

### Deploy to Production

[`deploy_production.yml`](.github/workflows/deploy_production.yml) has three triggers. Runs never overlap: they queue on the `deploy-production` concurrency group, and a queued run doesn't cancel one in progress.

**Push to `main` (merge):** a state-based deploy.
- `dbt build --select state:modified+ --defer --state target_prod --full-refresh`: only what changed since the last successful production run, plus everything downstream.

**Daily schedule, 10:00 UTC (`0 10 * * *`):** a full run.
- `dbt compile`, `dbt source freshness`, then `dbt build` of the **whole project**.

**Manual (`workflow_dispatch`):** a full run with optional args.
- Actions → *Deploy to Production* → *Run workflow*. The `dbt-args` input is appended to `dbt build`, for example:
  - `--select fct_facebook_ads_stats_daily`
  - `--select fct_facebook_ads_stats_daily --full-refresh`
  - leave empty to build everything

Every production run then:
1. Generates dbt docs, the docglow site and the dbt-colibri report, uploading `dbt-docs-production`, `docglow-production` and `colibri-production`.
2. Uploads `target/manifest.json` as **`dbt-prod-manifest`**. This becomes the state that CI, staging and the next production deploy compare against.
3. Runs Elementary against the `production` profile and uploads `elementary-report-production`. This runs even if the build failed.

### How the build decides what to run

The **Build all dbt** step in [`dbt_ci_cd`](.github/actions/dbt_ci_cd/action.yml) picks the first matching case:

| Case | Command |
|---|---|
| Full run (schedule / manual) | `dbt build $DBT_ARGS` |
| No production manifest available (`HAS_PROD_STATE=false`) | `dbt build --full-refresh` |
| `ci` target | `dbt build --select state:modified+1 --defer --state target_prod --indirect-selection=buildable --fail-fast` |
| `staging` / `production` push | `dbt build --select state:modified+ --defer --state target_prod --full-refresh` |

`HAS_PROD_STATE` is `false` only when no `dbt-prod-manifest` artifact exists. That happens before the first production run, or if production hasn't succeeded for 90 days and the artifact has expired.

### Artifacts: manifest, docs and Elementary report

The pipeline stores its outputs as **GitHub Actions artifacts** (90-day retention). There is no S3 or other external storage.

| Artifact | Produced by | Contents |
|---|---|---|
| `dbt-prod-manifest` | Production runs | `manifest.json` used for `state:modified` comparisons |
| `dbt-docs-production` / `dbt-docs-staging` | Production / staging runs | `static_index.html`, self-contained dbt docs |
| `docglow-production` / `docglow-staging` | Production / staging runs | `index.html`, self-contained docglow site with column-level lineage |
| `colibri-production` / `colibri-staging` | Production / staging runs | `index.html`, self-contained dbt-colibri column-lineage report |
| `elementary-report-production` / `elementary-report-staging` | Production / staging runs | `elementary_report.html` |

**To view the docs or the Elementary report:** open a successful run under **Actions**, download the artifact from the **Artifacts** section at the bottom, unzip it and open the HTML file in a browser. From the terminal:

```bash
gh run download $(gh run list --repo victoredo/cdc_modelling --workflow deploy_production.yml --status success --limit 1 --json databaseId --jq '.[0].databaseId') --repo victoredo/cdc_modelling --name dbt-docs-production --dir ~/Downloads/dbt-docs && open ~/Downloads/dbt-docs/static_index.html
```

Swap `dbt-docs-production` for `elementary-report-production` to get the Elementary report.

### Secrets and settings

Configured under **Settings → Secrets and variables → Actions**:

| Name | Type | Used for |
|---|---|---|
| `DBX_ID_APPLICATION_ID` | Secret | Databricks service principal client ID (`ci`, `staging`, `production` targets) |
| `DBX_SECRET` | Secret | Databricks service principal client secret |

The workflows use the built-in `GITHUB_TOKEN` (with `actions: read`) to find and download the production manifest from earlier runs. No other token is needed.

The **`deploy-to-staging`** label must exist in the repo for the staging workflow to be usable.

---

## Conventions

- **Naming:** `stg_<source>_<entity>` → `int_<source>_<entity>` → `dim_` / `fct_`. Every model has a `.yml` next to it with a description and tests.
- **SQL style:** enforced by sqlfluff ([`cdc_marketing/.sqlfluff`](cdc_marketing/.sqlfluff)): Databricks dialect, 120-character lines, rules `AM04`, `RF02`, `RF03`, `ST06` excluded. Jinja templating errors are ignored, since dbt-only objects like `flags` don't exist when sqlfluff renders the SQL.
- **Microbatch models** (e.g. `fct_facebook_ads_stats_daily`):
  - `materialized='table' if flags.FULL_REFRESH else 'incremental'`: a full refresh rebuilds the table in one query instead of one query per batch.
  - `begin` is the real start date only on `production`. Everywhere else it's *now*, so CI and dev only build the latest batch instead of backfilling all history.
- **Dev row limit:** add `{{ add_rows_limit() }}` to staging models so `dev`/`ci` runs work on at most 1000 rows.
