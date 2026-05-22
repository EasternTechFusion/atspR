# Getting Started with atspR

## Overview

`atspR` (**Automated Time-Series Preprocessing in R**) provides a
complete, modular preprocessing framework for time-series data — from
raw input to cross-validated, model-ready datasets.

------------------------------------------------------------------------

## Installation

``` r

devtools::install_github("EasternTechFusion/atspR")
```

------------------------------------------------------------------------

## Case 1: Date + Time in separate columns

[`combine_datetime()`](https://easterntechfusion.github.io/atspR/reference/combine_datetime.md)
รองรับ `time_type` 3 แบบ:

| `time_type` | ตัวอย่าง        | คำอธิบาย         |
|-------------|---------------|-----------------|
| `"hour"`    | `8`, `14`     | Integer 0–23    |
| `"hhmm"`    | `830`, `1430` | Integer HHMM    |
| `"string"`  | `"08:30"`     | Character HH:MM |

``` r

library(atspR)

# combine date + time columns → POSIXct
df <- combine_datetime(my_data,
                       date_col  = "Date",
                       time_col  = "Time",
                       new_col   = "datetime",
                       time_type = "string")

# fill missing timestamp rows (e.g. hour 10:00 absent)
gap <- fill_time_gaps(df,
                      time_col = "datetime",
                      n        = 1,
                      unit     = "hour")

result <- ts_preprocess(
  data        = gap$data,
  train_ratio = 0.8,
  target_col  = "VPD",
  k_folds     = 5L
)
```

------------------------------------------------------------------------

## Case 2: Datetime in one column

``` r

df_datetime <- data.frame(
  datetime = as.POSIXct(
    c("2024-01-01 08:00:00", "2024-01-01 09:00:00",
      "2024-01-01 11:00:00", "2024-01-01 12:00:00"),
    format = "%Y-%m-%d %H:%M:%S"
  ),
  Temp  = c(25.12, NA,    26.26, 27.07),
  Humid = c(80.04, 82.38, 85.03, 83.57),
  VPD   = c(0.276, 0.312, 0.389, 0.402)
)

# fill missing timestamp rows (e.g. hour 10:00 absent)
gap <- fill_time_gaps(df_datetime,
                      time_col = "datetime",
                      n        = 1,
                      unit     = "hour")

result <- ts_preprocess(
  data        = gap$data,
  train_ratio = 0.8,
  target_col  = "VPD",
  k_folds     = 5L
)
```

------------------------------------------------------------------------

## Case 3: Date only (daily data)

``` r

df_daily <- data.frame(
  date = as.Date(c("2024-01-01", "2024-01-02", "2024-01-04", "2024-01-05")),
  Temp  = c(28.38, 29.16, 27.89, 26.50),
  Humid = c(75.04, 72.05, 78.03, 80.54),
  VPD   = c(0.276, 0.312, 0.389, 0.302)
)

# fill missing timestamp rows (e.g. 2024-01-03 absent)
gap <- fill_time_gaps(df_daily,
                      time_col = "date",
                      n        = 1,
                      unit     = "day")

result <- ts_preprocess(
  data        = gap$data,
  train_ratio = 0.8,
  target_col  = "VPD",
  k_folds     = 5L
)
```

------------------------------------------------------------------------

## Walk-Forward Cross-Validation

`atspR` uses **walk-forward validation** — the correct approach for
time-series. Each fold’s validation set always follows its training set
in time.

    Seed(20%)  Fold1  Fold2  Fold3  Fold4  Fold5
    [─────────][─────][─────][─────][─────][─────]

    Fold 1: train = seed              → val = fold1
    Fold 2: train = seed + fold1      → val = fold2
    Fold 3: train = seed + fold1+2    → val = fold3

------------------------------------------------------------------------

## Export Results

``` r

ts_export(result, dir = "output", prefix = "data")
# Saves:
#   output/data_train_scaled.csv
#   output/data_test_scaled.csv
#   output/data_data_clean.csv
```

------------------------------------------------------------------------

## Available Functions

| Function | Description |
|----|----|
| [`standardize_na()`](https://easterntechfusion.github.io/atspR/reference/standardize_na.md) | Convert custom missing indicators to `NA` |
| [`coerce_numeric()`](https://easterntechfusion.github.io/atspR/reference/coerce_numeric.md) | Auto-convert character columns to numeric |
| [`combine_datetime()`](https://easterntechfusion.github.io/atspR/reference/combine_datetime.md) | Merge date + time columns → `POSIXct` |
| [`fill_time_gaps()`](https://easterntechfusion.github.io/atspR/reference/fill_time_gaps.md) | Insert missing timestamp rows |
| [`missing_analysis()`](https://easterntechfusion.github.io/atspR/reference/missing_analysis.md) | Analyse & visualise missing values |
| [`handle_missing()`](https://easterntechfusion.github.io/atspR/reference/handle_missing.md) | Drop rows or impute (linear / KNN) |
| [`visualize_data()`](https://easterntechfusion.github.io/atspR/reference/visualize_data.md) | Scatter plots per variable |
| [`split_data()`](https://easterntechfusion.github.io/atspR/reference/split_data.md) | Temporal train / test split |
| [`scale_data()`](https://easterntechfusion.github.io/atspR/reference/scale_data.md) | Feature scaling (auto / minmax / zscore / robust) |
| [`inverse_scale()`](https://easterntechfusion.github.io/atspR/reference/inverse_scale.md) | Reverse scaling to original units |
| [`cross_validate()`](https://easterntechfusion.github.io/atspR/reference/cross_validate.md) | Walk-forward k-fold CV |
| [`ts_preprocess()`](https://easterntechfusion.github.io/atspR/reference/ts_preprocess.md) | Run all steps in one call |
| [`ts_export()`](https://easterntechfusion.github.io/atspR/reference/ts_export.md) | Export results to CSV |
