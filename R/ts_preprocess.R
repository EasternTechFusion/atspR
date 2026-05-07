# =============================================================================
# atspR/R/ts_preprocess.R
# Master orchestrator
# =============================================================================

#' Run the Full Preprocessing Pipeline
#'
#' Executes all pipeline steps in order:
#' \enumerate{
#'   \item [standardize_na()]  - convert custom missing indicators to NA
#'   \item [coerce_numeric()]  - auto-convert character cols to numeric
#'   \item [fill_time_gaps()]  - insert missing timestamps (optional)
#'   \item [split_data()]      - temporal train/test split (before imputation)
#'   \item [missing_analysis()] - assess missing values on train only
#'   \item [handle_missing()]   - impute/drop train; forward-fill test from train tail
#'   \item [visualize_data()]   - scatter plots per variable vs index
#'   \item [scale_data()]       - feature scaling (fit on train only)
#'   \item [cross_validate()]   - k-fold CV on training set (optional)
#' }
#'
#' @param data A `data.frame` with rows ordered by time.
#' @param na_strings Character vector. Extra strings to treat as `NA`,
#'   e.g. `c("-", "Missing", "N/A")`. Built-in defaults already cover
#'   common patterns. Default `character(0)`.
#' @param na_numbers Numeric vector. Numeric sentinel values to treat as `NA`,
#'   e.g. `c(-999, 9999)`. Default `NULL`.
#' @param min_success_rate Numeric in (0, 1]. Minimum fraction of non-NA values
#'   that must parse as numbers for a character column to be converted to numeric.
#'   Default `0.8`.
#' @param train_ratio Numeric in (0, 1). Default `0.8`.
#' @param impute_method `"linear"` (default) or `"knn"`.
#' @param scale_method `"auto"` (default) auto-selects based on outlier detection,
#'   or one of `"minmax"`, `"zscore"`, `"robust"`.
#' @param target_col Character. Response column for cross-validation.
#'   If `NULL` (default), CV is skipped.
#' @param k_folds Integer. Number of CV folds. Default `5`.
#' @param model_fn Optional custom model function for CV.
#' @param verbose Logical (default `TRUE`).
#'
#' @return An invisible list with elements:
#' \describe{
#'   \item{`data_clean`}{Cleaned data.frame.}
#'   \item{`train`}{Unscaled training set.}
#'   \item{`test`}{Unscaled test set.}
#'   \item{`train_scaled`}{Scaled training set -- ready for modelling.}
#'   \item{`test_scaled`}{Scaled test set.}
#'   \item{`scale_params`}{Scaling parameters (fitted on train only).}
#'   \item{`scale_method`}{Scaling method used.}
#'   \item{`missing_report`}{Per-variable NA summary table.}
#'   \item{`imputation_report`}{String describing the action taken.}
#'   \item{`cv_summary`}{CV summary data.frame, or NULL if skipped.}
#'   \item{`cv_folds`}{Per-fold CV results, or NULL if skipped.}
#'   \item{`plots`}{Named list: boxplot, scatter.}
#'   \item{`before_after`}{Before/after imputation sample, or NULL.}
#' }
#'
#' @examples
#' data(airquality)
#'
#' # Basic usage
#' result <- ts_preprocess(
#'   data         = airquality,
#'   train_ratio  = 0.8,
#'   scale_method = "minmax"
#' )
#' head(result$train_scaled)
#'
#' # With custom NA indicators
#' result <- ts_preprocess(
#'   data       = airquality,
#'   na_strings = c("-", "Missing"),
#'   na_numbers = c(-999),
#'   scale_method = "minmax"
#' )
#'
#' @export
ts_preprocess <- function(data,
                          na_strings    = character(0),
                          na_numbers    = NULL,
                          min_success_rate = 0.8,
                          train_ratio   = 0.8,
                          impute_method = "linear",
                          impute_tail_n = 10L,
                          scale_method  = "auto",
                          target_col    = NULL,
                          k_folds       = 5L,
                          model_fn      = NULL,
                          verbose       = TRUE) {

  .check_df(data)

  if (verbose) {
    .header("atspR  |  Automated Time Series Preprocessing")
    cat(sprintf("  Input : %d rows, %d cols  |  Train/Test: %.0f%%/%.0f%%  |  Impute: %s  |  Scale: %s\n",
                nrow(data), ncol(data),
                train_ratio * 100, (1 - train_ratio) * 100,
                impute_method, scale_method))
    cat(sprintf("  CV    : target = %s,  k = %d\n",
                if (!is.null(target_col)) target_col else "none (skipped)", k_folds))
    cat(strrep("-", 60), "\n", sep = "")
  }

  # Step 1: Standardise missing indicators
  data <- standardize_na(data,
                         na_strings = na_strings,
                         na_numbers = na_numbers,
                         verbose    = FALSE)

  # Step 2: Coerce character columns to numeric
  data <- coerce_numeric(data,
                         min_success_rate = min_success_rate,
                         verbose          = FALSE)

  # Step 3: Split FIRST -- before any imputation to prevent leakage
  sp_raw <- split_data(data, train_ratio = train_ratio, verbose = FALSE)

  # Step 4: Missing analysis on TRAIN only
  ana <- missing_analysis(sp_raw$train, plot = TRUE, verbose = FALSE)

  # Step 5: Impute / drop TRAIN only
  clean_train <- handle_missing(ana, method = impute_method, verbose = FALSE)

  # Step 6: Impute TEST using train tail (forward-fill only -- no leakage)
  #         Drop rows when action was "drop" (mirror train decision on test)
  if (clean_train$action == "drop") {
    test_clean <- sp_raw$test[stats::complete.cases(sp_raw$test), ]
  } else {
    test_clean <- .impute_test_with_train_tail(
      test   = sp_raw$test,
      train  = clean_train$data_clean,
      method = impute_method,
      tail_n = impute_tail_n
    )
  }

  # Reassemble a split-result-like object for downstream steps
  sp <- list(
    train     = clean_train$data_clean,
    test      = test_clean,
    train_idx = sp_raw$train_idx,
    test_idx  = sp_raw$test_idx,
    ratio     = sp_raw$ratio
  )

  # Step 7: Visualise (on cleaned train)
  viz <- visualize_data(clean_train, raw_data = sp_raw$train, verbose = FALSE)

  # Step 8: Scale -- fit on train only, apply to test
  sc <- scale_data(sp, method = scale_method, verbose = FALSE)

  # -- Print unified pipeline summary ----------------------------------------
  if (verbose) {
    miss_cols  <- sum(ana$summary$n_missing > 0)
    n_train    <- nrow(sp_raw$train)
    n_train_clean <- nrow(clean_train$data_clean)
    n_test     <- nrow(test_clean)

    miss_reason <- if (n_train <= 50) {
      sprintf("n = %d <= 50, always impute", n_train)
    } else if (ana$overall_pct > 0.05) {
      sprintf("missing = %.2f%% > 5%% threshold", ana$overall_pct * 100)
    } else {
      sprintf("missing = %.2f%% <= 5%% threshold, safe to drop", ana$overall_pct * 100)
    }
    miss_action <- if (clean_train$action == "drop") "DROP" else paste0("IMPUTE (", toupper(clean_train$method), ")")

    cat(sprintf("  [1/9] Standardise NA indicators  -- done\n\n"))

    cat(sprintf("  [2/9] Coerce character cols to numeric  -- done\n\n"))

    cat(sprintf("  [3/9] Train / Test Split  (before imputation)\n"))
    cat(sprintf("        Train: %d rows (%.0f%%)  |  Test: %d rows (%.0f%%)\n\n",
                nrow(sp_raw$train), sp_raw$ratio["train"] * 100,
                nrow(sp_raw$test),  sp_raw$ratio["test"]  * 100))

    cat(sprintf("  [4/9] Missing Value Analysis  (train only)\n"))
    cat(sprintf("        %.2f%%  |  %d / %d cols  |  %s  -- %s\n\n",
                ana$overall_pct * 100, miss_cols, ncol(sp_raw$train),
                miss_action, miss_reason))

    cat(sprintf("  [5/9] Handle Missing Values  (train)\n"))
    if (clean_train$action == "drop") {
      cat(sprintf("        %d -> %d rows  (-%d dropped)\n\n",
                  n_train, n_train_clean, n_train - n_train_clean))
    } else {
      cat(sprintf("        %d cells imputed", clean_train$n_imputed))
      imp_cols <- colSums(as.matrix(clean_train$imputed_mask))
      imp_cols <- sort(imp_cols[imp_cols > 0], decreasing = TRUE)
      if (length(imp_cols) > 0)
        cat(sprintf("  [%s]",
                    paste(sprintf("%s:%d", names(imp_cols), imp_cols), collapse = "  ")))
      cat("\n\n")
    }

    cat(sprintf("  [6/9] Handle Missing Values  (test -- forward-fill from train tail)\n"))
    n_test_na_before <- sum(is.na(sp_raw$test))
    n_test_na_after  <- sum(is.na(test_clean))
    cat(sprintf("        %d NA cells filled  |  tail_n = %d rows used\n\n",
                n_test_na_before - n_test_na_after, impute_tail_n))

    cat(sprintf("  [7/9] Visualise\n"))
    cat(sprintf("        %d scatter page(s) generated\n\n", length(viz$scatter_plots)))

    cat(sprintf("  [8/9] Feature Scaling  [%s]\n", toupper(sc$method)))
    if (!is.null(sc$method_reason))
      cat(sprintf("        Auto-selected : %s\n", sc$method_reason))
    n_scaled   <- length(sc$cols)
    out_cols   <- sc$outlier_ratio[sc$outlier_ratio > 0]
    out_sorted <- sort(out_cols, decreasing = TRUE)
    cat(sprintf("        Columns scaled : %d  (%s)\n",
                n_scaled,
                if (n_scaled <= 4) paste(sc$cols, collapse = ", ")
                else paste(c(sc$cols[1:3], "..."), collapse = ", ")))
    if (length(out_sorted) > 0) {
      cat(sprintf("        Outliers       : %s\n",
                  paste(sprintf("%s(%.1f%%)", names(out_sorted), out_sorted * 100),
                        collapse = "  ")))
      if (toupper(sc$method) == "ROBUST") {
        cat(sprintf("        [OK] Outlier(s) detected -> robust scaling applied\n"))
      } else {
        cat(sprintf("        [!]  Outlier(s) detected but method = \"%s\" was forced\n",
                    sc$method))
        cat(sprintf("             -> set scale_method = \"auto\" or \"robust\" to handle correctly\n"))
      }
    } else {
      cat("        [OK] No outliers detected\n")
    }
    cat("\n")
    cat(strrep("-", 60), "\n", sep = "")
  }

  # Step 9: Cross-validate (optional)
  cv_summary <- NULL
  cv_folds   <- NULL

  if (!is.null(target_col)) {
    cv         <- cross_validate(sc,
                                 target_col = target_col,
                                 model_fn   = model_fn,
                                 k          = k_folds,
                                 verbose    = verbose)
    cv_summary <- cv$summary
    cv_folds   <- cv$fold_results
  }

  invisible(list(
    data_clean        = clean_train$data_clean,
    train             = sp$train,
    test              = sp$test,
    train_scaled      = sc$train_scaled,
    test_scaled       = sc$test_scaled,
    scale_params      = sc$params,
    scale_method      = sc$method,
    missing_report    = ana$summary,
    imputation_report = clean_train$report,
    cv_summary        = cv_summary,
    cv_folds          = cv_folds,
    plots = list(
      boxplot = ana$plot,
      scatter = viz$scatter_plots
    ),
    before_after = viz$before_after
  ))
}
