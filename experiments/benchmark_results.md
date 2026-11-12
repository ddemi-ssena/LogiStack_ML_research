# Churn Model Benchmark

Results below were computed from the local PostgreSQL warehouse during the report-generation run. Snapshot baseline models use the same single-snapshot cohort and stratified split; production XGBoost uses the three-window pooled cohort and customer-grouped split. Scores are therefore useful as the project's recorded results, but are not all measured on identical test rows.

| Model | Cohort/split | ROC-AUC | PR-AUC | F1 | Accuracy | Confusion matrix `[[TN,FP],[FN,TP]]` |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Logistic Regression (balanced) | Single snapshot | 0.7033 | 0.9823 | 0.8179 | 0.6980 | `[[7,7],[99,238]]` |
| Random Forest (balanced) | Single snapshot | 0.6872 | 0.9785 | 0.9752 | 0.9516 | `[[0,14],[3,334]]` |
| LightGBM (balanced) | Single snapshot | 0.6617 | 0.9779 | 0.9613 | 0.9259 | `[[2,12],[14,323]]` |
| **XGBoost (Sliding Window, production)** | **Three windows, group split** | **0.7398** | **0.9781** | **0.8998** | **0.8230** | **`[[20,19],[109,575]]`** |

## Production sliding-window run

- Snapshots: 2017-10-01, 2017-12-15, and 2018-03-04; each uses a 180-day future outcome horizon.
- Pooled data: 3,678 rows; training/test: 2,955 / 723 rows.
- `customer_unique_id` group overlap across train and test: 0.
- Precision: 0.9680; Recall: 0.8406; F1: 0.8998; Accuracy: 0.8230; ROC-AUC: 0.7398; PR-AUC: 0.9781.
- Feature importance: frequency 0.30881298; recency_days 0.22762957; monetary 0.17091279; avg_item_price 0.15088978; avg_review_score 0.14175487.
- Confusion matrix label order: `[[TN, FP], [FN, TP]]`.

## RFM segmentation

K-Means with k=4 produced these data-derived segment sizes from 93,106 valid customer rows: Champions 2,789; Loyal 16,843; At Risk 37,260; Hibernating 36,214.

Re-running on a changed database snapshot or dependency versions may produce different results. The report figures are static copies of the generated local run and are not recalculated by this benchmark file.
