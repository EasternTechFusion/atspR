# atspR ![](reference/figures/logo.png)

> **Automated Time-Series Preprocessing in R**

## Overview

`atspR` is an R package that provides an automated, modular
preprocessing pipeline for time-series data covering the full journey
from raw sensor data to cross-validated, model-ready train and test
sets.

The package is designed for students and domain practitioners
(agronomists, environmental scientists, irrigation engineers) who work
primarily in R and need a reliable, leakage-free preprocessing workflow
without having to manage multiple packages or worry about the correct
sequencing of steps.

### Why atspR?

| Problem | How atspR solves it |
|----|----|
| Scalers applied before splitting → **data leakage** | Scaler fitted on **TRAIN only**, applied to both sets |
| Random split invalidates time-series models | **Temporal split** — train always precedes test chronologically |
| Irregular sensor timestamps break time-series assumptions | [`fill_time_gaps()`](https://easterntechfusion.github.io/atspR/reference/fill_time_gaps.md) snaps data onto a **regular time grid**, flagging missing points as `NA` |
| Silent NA removal with no record | Full report of what was dropped or imputed, and why |
| Multi-package workflow, easy to sequence incorrectly | Single function [`ts_preprocess()`](https://easterntechfusion.github.io/atspR/reference/ts_preprocess.md) runs all 8 steps in order |
| One-size-fits-all model choice | [`cross_validate()`](https://easterntechfusion.github.io/atspR/reference/cross_validate.md) supports multiple model types (**Linear Regression (lm) / Generalized Additive Model (gam) / Random Forest (rf)/ Decision Tree (dt)**) |
| Error messages with no guidance | Every automated decision explained in plain-language output |

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

# Install from GitHub
# install.packages("devtools")
devtools::install_github("EasternTechFusion/atspR")
```

## Quick Start

## Univariate

**Sample data**

| DateTime         | WaterLevel |
|------------------|------------|
| 2024-01-01 08:00 | 3.31       |
| 2024-01-01 08:10 | 3.37       |
| 2024-01-01 08:20 | 3.46       |
| 2024-01-01 08:33 | 3.53       |
| 2024-01-01 08:42 | 3.56       |
| 2024-01-01 08:59 | 3.58       |
| 2024-01-01 09:10 | 3.60       |
| 2024-01-01 09:24 | 3.62       |

> Raw sensor readings arrive at irregular intervals (roughly every 10
> minutes) —
> [`fill_time_gaps()`](https://easterntechfusion.github.io/atspR/reference/fill_time_gaps.md)
> snaps them onto a regular 10-minute grid, inserting `NA` for any grid
> point with no matching reading.

> This dataset has only one variable (`WaterLevel`), so
> [`ts_preprocess()`](https://easterntechfusion.github.io/atspR/reference/ts_preprocess.md)
> runs in univariate mode — no exogenous features are used.

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

**Sample data**

| Date       | Time  | Temp  | Humid | Solar   | WindSpeed | RainFall | VPD    |
|------------|-------|-------|-------|---------|-----------|----------|--------|
| 2024-01-01 | 08:00 | 25.12 | 80.04 | 14.0591 | 0.0000    | 0.0000   | 0.2758 |
| 2024-01-01 | 09:00 | NA    | 82.38 | 18.3274 | 0.5200    | 0.0000   | 0.3124 |
| 2024-01-01 | 11:00 | 26.26 | 85.03 | 22.7810 | 1.1400    | 0.0000   | 0.3892 |
| 2024-01-01 | 12:00 | 27.07 | 83.57 | NA      | 1.3300    | 0.1200   | 0.4015 |

> Hour 10:00 is missing entirely —
> [`fill_time_gaps()`](https://easterntechfusion.github.io/atspR/reference/fill_time_gaps.md)
> will insert it as a row of `NA`.

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

result <- ts_preprocess(data         = gap$data,
                        train_ratio  = 0.8,
                        target_col   = "VPD",
                        k_folds      = 5)
```

### Case 2: Datetime in one column

**Sample data**

| DateTime         | Temp  | Humid | Solar   | WindSpeed | RainFall | VPD    |
|------------------|-------|-------|---------|-----------|----------|--------|
| 2024-01-01 08:00 | 25.12 | 80.04 | 14.0591 | 0.0000    | 0.0000   | 0.2758 |
| 2024-01-01 09:00 | NA    | 82.38 | 18.3274 | 0.5200    | 0.0000   | 0.3124 |
| 2024-01-01 11:00 | 26.26 | 85.03 | 22.7810 | 1.1400    | 0.0000   | 0.3892 |
| 2024-01-01 12:00 | 27.07 | 83.57 | NA      | 1.3300    | 0.1200   | 0.4015 |

> Hour 10:00 is missing entirely —
> [`fill_time_gaps()`](https://easterntechfusion.github.io/atspR/reference/fill_time_gaps.md)
> will insert it as a row of `NA`.

``` r

library(atspR)

df$datetime <- as.POSIXct(df$datetime, 
                          format = "%Y-%m-%d %H:%M:%S")
                          
gap <- fill_time_gaps(df, 
                      time_col = "datetime", 
                      n = 1, 
                      unit = "hour")
                      
result <- ts_preprocess(data         = gap$data,
                        train_ratio  = 0.8,
                        target_col   = "VPD",
                        k_folds      = 5)
```

### Case 3: Date only (daily data)

**Sample data**

| date       | Temp  | Humid | Solar   | WindSpeed | RainFall | VPD      |
|------------|-------|-------|---------|-----------|----------|----------|
| 2024-01-01 | 28.38 | 75.04 | 14.0591 | 0.0000    | 0.0000   | 0.275835 |
| 2024-01-02 | 29.16 | 72.05 | NA      | 0.5200    | 0.0000   | 0.312410 |
| 2024-01-04 | 27.89 | 78.03 | 22.7810 | 1.1400    | 2.4000   | 0.389200 |
| 2024-01-05 | 26.50 | 80.54 | 19.4320 | 0.8800    | 0.0000   | 0.301770 |

> 2024-01-03 is missing entirely —
> [`fill_time_gaps()`](https://easterntechfusion.github.io/atspR/reference/fill_time_gaps.md)
> will insert it as a row of `NA`.

``` r

library(atspR)

gap <- fill_time_gaps(df, 
                      time_col = "date", 
                      n = 1, 
                      unit = "day")
                      
result <- ts_preprocess(data         = gap$data,
                        train_ratio  = 0.8,
                        target_col   = "VPD",
                        k_folds      = 5)
```

## Export Results

``` r
ts_export(result, dir = "C:\Users\user\", prefix = "data")
```

## Cross-Validation

`atspR` uses **walk-forward validation** — the correct approach for
time-series data. Each validation fold is always preceded only by past
data, so no future information leaks into training.

    Seed(20%)  Fold1  Fold2  Fold3  Fold4  Fold5
    [─────────][─────][─────][─────][─────][─────]

    Fold 1: train = seed              → val = fold1
    Fold 2: train = seed + fold1      → val = fold2
    Fold 3: train = seed + fold1+2    → val = fold3
    ...

## Citation

    Sueppong Mueanchamnong and Pattharaporn Thongnim (2026). atspR: Automated Time-Series Preprocessing in R.
    R package version 1.1.0
    https://github.com/EasternTechFusion/atspR

## License

MIT © 2024
