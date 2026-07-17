# atspR — Getting Started

------------------------------------------------------------------------

## Pipeline

    Raw data
       │
       ├─ (Stage 1) combine_datetime()      Merge date + time columns → POSIXct (optional)
       ├─ (Stage 2) fill_time_gaps()        Insert placeholder rows for missing timestamps
       │
       └─ ts_preprocess()                   ────────────────── 8 steps ──────────────────────────────
       │    (Stage 3) standardize_na()      Convert sentinel values to NA
       │    (Stage 4) coerce_numeric()      Parse character columns to numeric
       │    (Stage 5) split_data()          Temporal train/test split
       │    (Stage 6) missing_analysis()    Summarise NAs; decide DROP or IMPUTE
       │    (Stage 7) handle_missing()      Drop rows or interpolate (linear/KNN)
       │    (Stage 8) visualize_data()      Scatter plots per variable vs time
       │    (Stage 9) scale_data()          MinMax / Z-score / Robust (auto)
       │    (Stage 10) cross_validate()     Walk-forward k-fold CV (optional) — choose one : 
       |                                    Linear Regression (lm)/ Generalized Additive Model (gam)/
       │                                    Random Forest (rf)/ Decision Tree (dt)
       │
       └─ ts_export()                       Write all outputs to CSV

------------------------------------------------------------------------

## Installation

``` r

# install.packages("devtools")
devtools::install_github("EasternTechFusion/atspR")
library(atspR)
```

## Quick Start

> **Note:** Column names must not contain parentheses `(` `)` or the
> package will fail to parse them. For example, rename `WaterLevel()` to
> `WaterLevel` before passing the data to `atspR` functions.

## Univariate

``` r

library(atspR)

df$datetime <- as.POSIXct(df$datetime, 
                          format = "%Y-%m-%d %H:%M:%S")

gap <- fill_time_gaps(df,
                      time_col = "DateTime",
                      n        = 10,
                      unit     = "min")

result <- ts_preprocess(data          = gap$data,
                        train_ratio   = 0.8,
                        impute_method = "linear",
                        lags          = 24,
                        model_type    = "lm",
                        target_col    = "WaterLevel",
                        k_folds       = 5)
```

## Multivariate

### Case 1: Date + Time in separate columns

``` r

library(atspR)

df <- combine_datetime(my_data,
                       date_col  = "Date",
                       time_col  = "Time",
                       new_col   = "datetime",
                       time_type = "string")

gap <- fill_time_gaps(df,
                      time_col = "datetime",
                      n        = 1,
                      unit     = "hour")

result <- ts_preprocess(data        = gap$data,
                        train_ratio = 0.8,
                        target_col  = "VPD",
                        k_folds     = 5)
```

### Case 2: Datetime in one column

``` r

library(atspR)

df$datetime <- as.POSIXct(df$datetime, format = "%Y-%m-%d %H:%M:%S")

gap <- fill_time_gaps(df,
                      time_col = "datetime",
                      n        = 1,
                      unit     = "hour")

result <- ts_preprocess(data        = gap$data,
                        train_ratio = 0.8,
                        target_col  = "VPD",
                        k_folds     = 5)
```

### Case 3: Date only (daily data)

``` r

library(atspR)

gap <- fill_time_gaps(df,
                      time_col = "date",
                      n        = 1,
                      unit     = "day")

result <- ts_preprocess(data        = gap$data,
                        train_ratio = 0.8,
                        target_col  = "VPD",
                        k_folds     = 5)
```

------------------------------------------------------------------------

## `ts_preprocess()` Parameters

| Parameter | Type | Default | Description |
|----|----|----|----|
| `data` | data.frame | — | Input dataframe (after [`fill_time_gaps()`](https://easterntechfusion.github.io/atspR/reference/fill_time_gaps.md)) |
| `target_col` | character | `NULL` | Response column for CV; `NULL` skips CV |
| `train_ratio` | numeric \[0–1\] | `0.8` | Proportion of data used for training |
| `k_folds` | integer | `5` | Number of walk-forward CV folds |
| `impute_method` | character | `"linear"` | `"linear"` or `"knn"` |
| `scale_method` | character | `"auto"` | `"minmax"`, `"zscore"`, `"robust"`, or `"auto"` |

------------------------------------------------------------------------

## Export Results

``` r

ts_export(result, dir = "C:/Users/user/", prefix = "data")
```

------------------------------------------------------------------------

## Cross-Validation

`atspR` uses **walk-forward validation** — each fold is preceded only by
past data, so no future information leaks into training.

    Seed(20%)  Fold1  Fold2  Fold3  Fold4  Fold5
    [─────────][─────][─────][─────][─────][─────]

    Fold 1: train = seed              → val = fold1
    Fold 2: train = seed + fold1      → val = fold2
    Fold 3: train = seed + fold1-2    → val = fold3
    Fold 4: train = seed + fold1–3    → val = fold4
    Fold 5: train = seed + fold1–4    → val = fold5

------------------------------------------------------------------------

## Citation

    Sueppong Mueanchamnong and Pattharaporn Thongnim (2026).
    atspR: Automated Time-Series Preprocessing in R.
    R package version 1.1.0.
    https://github.com/EasternTechFusion/atspR

*MIT © 2024 · [GitHub
Repository](https://github.com/EasternTechFusion/atspR)*
