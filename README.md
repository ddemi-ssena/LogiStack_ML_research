# LogiStack ML Research

This repository contains the machine-learning research for **LogiStack**, an end-to-end e-commerce data engineering, streaming, and analytics project. The companion platform repository builds the PostgreSQL medallion warehouse and serves the selected churn model through its API.

- **Platform project:** [Softito_Logistack_Project](https://github.com/ddemi-ssena/Softito_Logistack_Project)
- **Research in this repository:** customer segmentation and repeat-purchase/churn model experiments
- **Data source:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), a public historical marketplace dataset covering 2016–2018

The ML code reads the platform's local PostgreSQL Gold and Silver tables. This repository does not contain the source CSVs, customer-level extracts, database dumps, passwords, or trained model binaries.

## Research questions

1. How can customers be grouped by historical purchase behavior using Recency, Frequency, and Monetary (RFM) features?
2. How well can repeat-purchase behavior over a future 180-day period be estimated from customer history?
3. How do Logistic Regression, Random Forest, LightGBM, and XGBoost compare, and does pooling temporal snapshots give a more robust evaluation cohort?

## Dataset and how it is used

The source is the Olist Brazilian E-Commerce Public Dataset published on Kaggle. The upstream LogiStack project loads the relevant order, customer, order-item, product, payment, and review CSVs into PostgreSQL Bronze, cleans/standardizes them into Silver, and builds analytical Gold facts and marts. Kafka data in the platform is a replay simulation of historical orders; it is not a separate live dataset used to train these models.

For the local warehouse run documented here, the six source tables contained these row counts:

| Source entity | Bronze rows | Silver rows | Gold input used by ML |
| --- | ---: | ---: | --- |
| Orders | 99,441 | 99,092 | `gold.fact_orders` (99,092) |
| Customers | 99,441 | 99,441 | `gold.dim_customers` (96,096 unique customer dimension rows) |
| Order items | 112,650 | 112,279 | `gold.fact_order_items` (112,279) |
| Payments | 103,886 | 103,520 | Not a direct churn/RFM model feature |
| Reviews | 99,224 | 98,879 | `silver.order_reviews.review_score` |
| Products | 32,951 | 32,951 | Not a direct churn/RFM model feature |

These are observed counts from one local database snapshot, not guaranteed counts for a newly loaded copy. The analytical Silver order layer covers purchases from 2017-01-01 through 2018-08-31; the raw Bronze layer also contains records outside that range or without an eligible purchase timestamp.

### Churn feature and label construction

For each snapshot, SQL reads historical orders strictly before the snapshot date and builds:

- `recency_days`: days since the customer's most recent historical order;
- `frequency`: historical order count;
- `monetary`: historical sum of product amounts;
- `avg_item_price`: mean historical order-item price;
- `avg_review_score`: mean historical review score where available.

The cohort includes customers with at least **two historical orders**. The binary target is `churn=1` when no order is observed in the next **180 days**, and `churn=0` when a future order is observed. Thus, class 1 means no repeat order in the observation window. The data is strongly imbalanced toward class 1 in the observed cohorts; interpret Accuracy, F1, PR-AUC, and confusion matrices with that label definition in mind.

The single-snapshot baseline uses the 2018-03-04 snapshot. The production experiment pools three 180-day windows: **2017-10-01**, **2017-12-15**, and **2018-03-04**. This gives the model examples from multiple points in the historical period while retaining a fully observed future label window.

### RFM segmentation data

The segmentation workflow reads `customer_unique_id`, `recency_days`, `frequency`, and `monetary` from `gold.mart_customer_rfm`. For the recorded run it used **93,106 valid customer rows**, log-transformed the three numeric features with `log1p`, standardized them, and fit K-Means with **k=4**, `n_init=10`, and `random_state=42`. The resulting counts were:

| Segment | Customers |
| --- | ---: |
| Champions | 2,789 |
| Loyal | 16,843 |
| At Risk | 37,260 |
| Hibernating | 36,214 |

Business labels are assigned from the resulting cluster RFM profiles; K-Means cluster IDs themselves have no fixed business meaning.

## Model comparison

The following values are from the recorded local database run. Logistic Regression, Random Forest, and LightGBM use the same single-snapshot cohort with a stratified 80/20 split (1,402 train / 351 test). Sliding Window XGBoost uses a different, pooled temporal cohort and a group split, so its test set is not identical to the baselines. The table is a transparent project comparison across the experiments, not a controlled same-test-set leaderboard.

| Model | Evaluation protocol | Precision | Recall | F1 | Accuracy | ROC-AUC | PR-AUC | Confusion matrix `[[TN,FP],[FN,TP]]` |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Logistic Regression (`class_weight=balanced`) | Single snapshot | 0.9714 | 0.7062 | 0.8179 | 0.6980 | 0.7033 | 0.9823 | `[[7,7],[99,238]]` |
| Random Forest (`class_weight=balanced`) | Single snapshot | 0.9598 | 0.9911 | 0.9752 | 0.9516 | 0.6872 | 0.9785 | `[[0,14],[3,334]]` |
| LightGBM (`class_weight=balanced`) | Single snapshot | 0.9642 | 0.9585 | 0.9613 | 0.9259 | 0.6617 | 0.9779 | `[[2,12],[14,323]]` |
| **XGBoost (selected production model)** | **Three-window, customer-grouped split** | **0.9680** | **0.8406** | **0.8998** | **0.8230** | **0.7398** | **0.9781** | **`[[20,19],[109,575]]`** |

Random Forest and LightGBM achieve higher F1/Accuracy on their single-snapshot test cohort, while production XGBoost is selected for the platform's temporally pooled, customer-isolated training/evaluation workflow. Its ROC-AUC is not the highest score among every displayed baseline because the evaluation protocols and test cohorts differ. The production split explicitly groups by `customer_unique_id`; measured customer overlap between train and test is **0**.

The three snapshots contain **726**, **1,199**, and **1,753** rows respectively, for **3,678 pooled rows**. The final grouped split has **2,955 training rows** and **723 test rows**. Sliding Window XGBoost feature importances (`feature_importances_`) rank as follows:

| Rank | Feature | Importance |
| ---: | --- | ---: |
| 1 | `frequency` | 30.88% |
| 2 | `recency_days` | 22.76% |
| 3 | `monetary` | 17.09% |
| 4 | `avg_item_price` | 15.09% |
| 5 | `avg_review_score` | 14.18% |

These importances describe this fitted model and are not causal effects.

## Report figures

The [`report_figures/`](report_figures/) directory contains 300-DPI PNG figures from the local analysis run:

1. [Customer order frequency](report_figures/fig1_order_frequency.png)
2. [Monthly order and revenue trend](report_figures/fig2_monthly_trend.png)
3. [RFM segment distribution](report_figures/fig3_rfm_segments.png)
4. [Model ROC-AUC and F1 comparison](report_figures/fig4_model_comparison.png)
5. [Sliding Window XGBoost confusion matrix](report_figures/fig5_confusion_matrix.png)
6. [XGBoost feature importances](report_figures/fig6_feature_importance.png)

The model comparison figure visualizes ROC-AUC and F1; consult the table above for all metrics and the test protocol.

## Repository contents

```text
.
├── analytics/                 # K-Means RFM segmentation
├── database/                  # ML-facing Gold mart contract
├── etl/                       # PostgreSQL connection helper
├── experiments/               # Cohort loaders and comparison training scripts
├── models/                    # Production sliding-window XGBoost trainer
├── report_figures/            # Report-ready PNG figures
├── .env.example               # Safe local DB config template
└── requirements.txt
```

## Setup

Requirements: Python 3.10+ and a PostgreSQL database already populated by the upstream LogiStack ETL with the tables in the [Gold/Silver data contract](#goldsilver-data-contract).

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Edit `.env` with your local PostgreSQL connection details. Do not commit `.env` or share credentials. The default example points to the upstream project's local Docker port `5434`; change it to match your setup.

## Run the experiments

Run these commands from the repository root after the upstream warehouse is available:

```powershell
python experiments/train_logistic_regression.py
python experiments/train_random_forest.py
python experiments/train_lightgbm.py
python experiments/train_sliding_xgboost.py
python models/train_churn.py
python analytics/customer_analysis.py
```

The experiment scripts print metrics and update their benchmark tracking files where configured. `models/train_churn.py` writes `models/churn_model.joblib`, which is ignored by Git. `analytics/customer_analysis.py` truncates and reloads `gold.mart_customer_segments`; run it only when you intend to replace that table's contents.

## Gold/Silver data contract

Churn training reads these columns:

| Table | Required columns |
| --- | --- |
| `gold.fact_orders` | `order_id`, `customer_unique_id`, `order_purchase_timestamp`, `order_status`, `total_product_amount` |
| `gold.fact_order_items` | `order_id`, `price` |
| `silver.order_reviews` | `order_id`, `review_score` |

RFM segmentation reads `gold.mart_customer_rfm(customer_unique_id, recency_days, frequency, monetary, reference_date)` and writes `gold.mart_customer_segments`; the required mart DDL is documented in [`database/01_ml_data_contract.sql`](database/01_ml_data_contract.sql). Base facts and the RFM source mart are built by the platform's ETL, not by this repository. Use [`database/05_ml_marts.sql`](database/05_ml_marts.sql) for the existing segment-mart definition.

## Reproducibility and data handling

- Snapshot dates, target horizon, cohort threshold, random seeds, and model parameters are defined in source code.
- Production validation uses a customer-grouped split and raises an error if customer IDs overlap between train and test.
- Scaler fitting for the production model uses training rows only.
- No source CSVs, customer-row extracts, database dump, credentials, or fitted model bundle should be committed here.
- Results may change with a new warehouse snapshot or dependency versions; record both when publishing an updated benchmark.

## Dataset terms

The Olist dataset remains subject to the terms of its [Kaggle dataset page](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Obtain source data from that page and follow its redistribution terms. This repository contains code and aggregate results, not copies of the source dataset.
