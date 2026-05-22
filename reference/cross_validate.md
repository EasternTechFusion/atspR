# K-Fold Cross-Validation on the Training Set

Performs walk-forward (time-ordered) k-fold cross-validation using a
user-supplied model function. Each validation fold is always preceded
only by past data, so no future information leaks into training.

## Usage

``` r
cross_validate(
  scale_result = NULL,
  train = NULL,
  target_col,
  model_fn = NULL,
  k = 5L,
  min_train_size = 0.2,
  verbose = TRUE
)
```

## Arguments

- scale_result:

  The list returned by
  [`scale_data()`](https://easterntechfusion.github.io/atspR/reference/scale_data.md);
  provides `train_scaled`. Alternatively, supply a plain `data.frame` to
  `train`.

- train:

  A `data.frame`. Used only when `scale_result` is `NULL`.

- target_col:

  Character. Name of the response column.

- model_fn:

  Function with signature `function(train_fold, val_fold)`. Must return
  a named numeric vector / list that includes at least one performance
  metric (e.g. `c(RMSE = ..., MAE = ..., R2 = ...)`). A simple
  linear-regression default is provided when `NULL`.

- k:

  Integer. Number of folds (default 5).

- min_train_size:

  Numeric in (0, 1). Fraction of rows reserved as seed training data
  before folding begins. Default `0.2` (20 %). This ensures fold 1
  always has training data available.

- verbose:

  Logical (default `TRUE`).

## Value

An invisible list with elements:

- `fold_results`:

  A `data.frame` with one row per fold.

- `summary`:

  A `data.frame` with mean and SD of each metric.

- `k`:

  Number of folds requested.

- `k_evaluated`:

  Number of folds actually evaluated.

- `min_train_size`:

  Seed fraction used.

- `target_col`:

  Response column name.

## Details

A seed training set of size `min_train_size` is reserved from the start
of the data before folding, guaranteeing every fold (including fold 1)
has enough data to train on.

## Examples

``` r
data(airquality)
clean <- airquality[complete.cases(airquality), ]
sp    <- split_data(clean, verbose = FALSE)
sc    <- scale_data(sp, verbose = FALSE)
cv    <- cross_validate(sc, target_col = "Ozone", k = 5)
#> 
#> ============================================================
#>   STEP : Walk-Forward Cross-Validation  (k = 5)
#> ============================================================
#> 
#>   Target : Ozone  |  Seed: 17 rows (20%)  |  Folds: 5 (~14 rows each)
#> 
#> ------------------------------------------------------------
#>   Results per fold
#> ------------------------------------------------------------
#>   RMSE / MAE = error (lower is better)  |  R2 = fit (closer to 1.0 is better)
#> 
#>   Fold    n_train     n_val     RMSE      MAE       R2      
#>   --------------------------------------------------------
#>   1       17          15        2.6864    1.7218    -0.4654 
#>   2       32          14        1.7235    1.2914    -0.1023 
#>   3       46          14        0.6952    0.5571    0.3811  
#>   4       60          14        0.5380    0.4337    0.5408  
#>   5       74          14        0.6793    0.3561    0.3935  
#> 
#> ------------------------------------------------------------
#>   Summary  (5/5 folds)
#> ------------------------------------------------------------
#>   mean = avg across folds  |  sd = consistency (lower = more stable)
#> 
#>   metric    mean      sd        min       max     
#>   ----------------------------------------------
#>   RMSE      1.2645    0.9256    0.5380    2.6864  
#>   MAE       0.8720    0.6032    0.3561    1.7218  
#>   R2        0.1495    0.4207    -0.4654   0.5408  
#> 
cv$summary
#>   metric   mean     sd     min    max
#> 1   RMSE 1.2645 0.9256  0.5380 2.6864
#> 2    MAE 0.8720 0.6032  0.3561 1.7218
#> 3     R2 0.1495 0.4207 -0.4654 0.5408
```
