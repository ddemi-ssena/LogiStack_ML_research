# Logistack ML Research

This repository contains the customer segmentation and repeat-purchase/churn experiments for the Logistack project. It reads analytical tables from the project's PostgreSQL Gold/Silver warehouse; it does not include source customer data, database dumps, credentials, or fitted model binaries.

## Scope

- K-Means RFM segmentation with four business-facing customer segments.
- Single-snapshot Logistic Regression, Random Forest, LightGBM, and XGBoost comparisons.
- Three-window, 180-day pooled XGBoost churn experiment with customer-grouped validation.
- SQL feature extraction directly from `gold.fact_orders`, `gold.fact_order_items`, and `silver.order_reviews`.
- Benchmark summaries and report-ready figures based on the project's local warehouse run.

The upstream data engineering project builds the warehouse. The expected table/column contract is described below and in [`database/01_ml_data_contract.sql`](database/01_ml_data_contract.sql). Apply the upstream project's database migrations/ETL before running any experiment. The SQL file here documents the ML-facing mart contract; it does not replace upstream ETL.

## Results from the recorded local run

The snapshot baselines use a stratified 80/20 split of the 2018-03-04 cohort. Production Sliding Window XGBoost pools three temporal cohorts and uses `GroupShuffleSplit` by `customer_unique_id`. The different split protocols mean this table is a project benchmark summary, not a claim that every model used the same test rows.

| Model | Evaluation data | ROC-AUC | PR-AUC | F1 | Accuracy |
| --- | --- | ---: | ---: | ---: | ---: |
| Logistic Regression (balanced) | Single snapshot | 0.7033 | 0.9823 | 0.8179 | 69.80% |
| Random Forest (balanced) | Single snapshot | 0.6872 | 0.9785 | 0.9752 | 95.16% |
| LightGBM (balanced) | Single snapshot | 0.6617 | 0.9779 | 0.9613 | 92.59% |
| **XGBoost (production)** | **Sliding Window** | **0.7398** | **0.9781** | **0.8998** | **82.30%** |

The sliding-window run pooled **3,678 rows** from snapshots **2017-10-01**, **2017-12-15**, and **2018-03-04** (180-day outcome horizon). The group split produced **2,955 training rows** and **723 test rows**, with **0 customer overlap**. Its confusion matrix in `[[TN, FP], [FN, TP]]` order is `[[20, 19], [109, 575]]`.

For production XGBoost, feature importances were `frequency` **30.88%**, `recency_days` **22.76%**, `monetary` **17.09%**, `avg_item_price` **15.09%**, and `avg_review_score` **14.18%**. Importances are model-relative and sum to 100% (rounding may apply).

RFM K-Means was run with **k=4** on **93,106 valid customers**. The observed segment counts were Champions **2,789**, Loyal **16,843**, At Risk **37,260**, and Hibernating **36,214**.

These values document the recorded local database run. Re-running the scripts against a different warehouse snapshot may produce different cohort sizes, splits, and scores. See [`experiments/benchmark_results.md`](experiments/benchmark_results.md) and [`report_figures/`](report_figures/) for the summary and figures.

## Repository layout

```text
.
├── analytics/                 # K-Means RFM segmentation
├── database/                  # ML mart DDL
├── etl/                       # PostgreSQL connection settings helper
├── experiments/               # Data loaders and model comparison experiments
├── models/                    # Production sliding-window XGBoost training
├── report_figures/            # Report-ready PNG outputs
├── .env.example               # Local PostgreSQL connection template
├── requirements.txt
└── README.md
```

## Requirements and setup

- Python 3.10 or newer
- PostgreSQL populated with the project's Silver and Gold analytical tables
- Read access to the tables listed in [Gold data contract](#gold-data-contract)
- Write access to `gold.mart_customer_segments` only when running the segmentation job

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Set the `.env` values for your local PostgreSQL. Keep `.env` local; never commit database passwords or customer-level extracts.

## Run experiments

Run commands from this repository's root directory:

```powershell
python experiments/train_logistic_regression.py
python experiments/train_random_forest.py
python experiments/train_lightgbm.py
python experiments/train_sliding_xgboost.py
python models/train_churn.py
python analytics/customer_analysis.py
```

The first four commands train and evaluate experiment models. `models/train_churn.py` trains the production sliding-window model and writes `models/churn_model.joblib`; that generated model artifact is ignored by Git. `analytics/customer_analysis.py` recalculates segments and replaces rows in `gold.mart_customer_segments`, so run it only when that write is intended.

## Gold data contract

The model loaders expect the following columns:

| Table | Required columns |
| --- | --- |
| `gold.fact_orders` | `order_id`, `customer_unique_id`, `order_purchase_timestamp`, `order_status`, `total_product_amount` |
| `gold.fact_order_items` | `order_id`, `price` |
| `silver.order_reviews` | `order_id`, `review_score` |
| `gold.mart_customer_rfm` | `customer_unique_id`, `recency_days`, `frequency`, `monetary`, `reference_date` |

The temporal loaders derive historical features before each snapshot and label whether an order occurs during the next 180 days. Only customers with at least two historical orders enter the churn cohort. Model code reads customer IDs to enforce group isolation; do not publish row-level data or database extracts.

For base fact table DDL, ETL, and fields used by the prediction API, see the upstream [Logistack data engineering repository](https://github.com/ddemi-ssena/Softito_Logistack_Project). The `gold.mart_customer_rfm` table is produced by that repository's Gold ETL; this repository documents the ML-facing contract and the segments mart.

## Reproducibility and data handling

- Snapshot dates, 180-day horizon, minimum historical order count, random seeds, and model parameters are defined in the Python source.
- The production sliding-window split groups by customer and checks that train/test customer IDs do not overlap.
- Preprocessing is fitted on training rows only.
- No row-level source data, `.env`, or trained `.joblib` artifact belongs in this repository.
- Metrics can change when the upstream Gold data or software versions change. Record the data snapshot and dependency versions when producing a new official benchmark.
