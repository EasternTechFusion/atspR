# Scale Numeric Features (Auto-Select Method)

Fits a scaler on the **training** set and applies the same parameters to
both train and test sets, preventing data leakage.

## Usage

``` r
scale_data(split_result, method = "auto", cols = NULL, verbose = TRUE)
```

## Arguments

- split_result:

  The list returned by
  [`split_data()`](https://easterntechfusion.github.io/atspR/reference/split_data.md).

- method:

  Character. One of `"auto"` (default), `"minmax"`, `"zscore"`, or
  `"robust"`. Use `"auto"` to let the function choose.

- cols:

  Character vector. Names of numeric columns to scale. `NULL` (default)
  scales all numeric columns.

- verbose:

  Logical (default `TRUE`).

## Value

An invisible list with elements:

- `train_scaled`:

  Scaled training `data.frame`.

- `test_scaled`:

  Scaled test `data.frame`.

- `params`:

  Per-column scaling parameters (fitted on train only).

- `method`:

  The scaling method used.

- `method_reason`:

  Why the method was selected (auto mode only).

- `outlier_ratio`:

  Named numeric vector of outlier ratios per column.

- `cols`:

  Character vector of scaled column names.

## Details

When `method = "auto"` (default), the scaling method is chosen
automatically based on per-column outlier detection (IQR method) and a
normality test (Shapiro-Wilk):

- **robust** – *any* outlier found in any column (IQR fence)

- **zscore** – no outliers + majority of columns approximately normal

- **minmax** – no outliers + majority of columns not normal

## Methods

- `minmax`:

  Scales each feature to \\\[0, 1\]\\.

- `zscore`:

  Standardises to zero mean and unit variance.

- `robust`:

  Uses median and IQR, robust to outliers.

## Examples

``` r
data(airquality)
clean <- airquality[complete.cases(airquality), ]
sp    <- split_data(clean, verbose = FALSE)
sc    <- scale_data(sp)
#> 
#> ============================================================
#>   STEP 7/7 : Feature Scaling  [ROBUST]
#> ============================================================
#> 
#>   Auto-selected : outlier detected in 2 column(s) [Ozone, Wind] -> robust
#>   Columns : 6  (Ozone, Solar.R, Wind, ...)
#>   Fitted on TRAIN only  |  Columns with outliers: 2 / 6
#> 
#> ------------------------------------------------------------
#>   Outlier ratio per column  (IQR)
#> ------------------------------------------------------------
#>  column outlier_pct
#>    Wind       3.41%
#>   Ozone       1.14%
#> 
#>   [OK] Outliers found in [Ozone, Wind] -> robust scaling applied
#> 
sc$method
#> [1] "robust"
sc$method_reason
#> [1] "outlier detected in 2 column(s) [Ozone, Wind] -> robust"
```
