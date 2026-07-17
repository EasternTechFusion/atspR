# =============================================================================
# atspR/R/fill_time_gaps.R
# Utility - Fill missing timestamps in time-series data
# =============================================================================

#' Fill Missing Timestamps in Time-Series Data
#'
#' Handles three types of timestamp trouble common in time-series:
#' \enumerate{
#'   \item **Drifted timestamps** - a reading scheduled for 13:05 was
#'     logged at 13:06 instead. For `unit \%in\% c("sec","min","hour","day")`,
#'     each observed timestamp is snapped to the nearest point on the
#'     regular grid, provided it falls within `tolerance` of that point.
#'     (Not applicable to `"month"`/`"quarter"`/`"year"`, whose calendar
#'     steps have no fixed duration - those units always use exact
#'     matching, as before.)
#'   \item **Missing rows** - timestamps that are absent entirely.
#'     These rows are inserted with `NA` for all value columns.
#'   \item **Missing values** - rows that exist but have `NA` in some columns.
#' }
#' After filling gaps the result is ready to pass into
#' [atspR::missing_analysis()] and [atspR::handle_missing()].
#'
#' tsibble and tibble inputs are automatically converted to `data.frame`.
#'
#' @param data A `data.frame`, `tibble`, or `tsibble` with a timestamp column,
#'   sorted ascending. tsibble and tibble are converted to `data.frame`
#'   automatically.
#' @param time_col Character. Name of the timestamp column
#'   (must be `Date` or `POSIXct`). Use [atspR::combine_datetime()] first if
#'   date and time are stored in separate columns.
#' @param n Numeric. Number of units per step. e.g. `1`, `3`, `15`.
#' @param unit Character. One of `"sec"`, `"min"`, `"hour"`, `"day"`,
#'   `"month"`, `"quarter"`, `"year"`.
#'   \itemize{
#'     \item `"month"`   - calendar months (1, 2, 3, ...)
#'     \item `"quarter"` - calendar quarters of 3 months each (Q1, Q2, Q3, Q4)
#'   }
#'   Note: `"month"` and `"quarter"` require the timestamp column to be `Date`
#'   and each value to fall on the first day of the month
#'   (e.g. `2024-01-01`, `2024-04-01`).
#' @param tolerance Numeric seconds, or `NULL`. Only used when
#'   `unit \%in\% c("sec","min","hour","day")`. Maximum distance an observed
#'   timestamp may sit from its nearest grid point and still be snapped to
#'   it. `NULL` (default) uses half the step size (`n`/`unit`), the widest
#'   tolerance that still avoids ambiguity between two adjacent grid
#'   points. Set to `0` to disable snapping and fall back to the legacy
#'   exact-match behavior (a timestamp must land exactly on the grid to
#'   count; otherwise it is left as-is and its grid slot is reported as a
#'   gap). Ignored (with a warning if non-`NULL`) for `"month"`,
#'   `"quarter"`, and `"year"`.
#' @param verbose Logical (default `TRUE`).
#'
#' @return An invisible list with elements:
#' \describe{
#'   \item{`data`}{Complete `data.frame` with no missing timestamps.
#'     Inserted rows have `NA` for all value columns.}
#'   \item{`n_gaps`}{Number of timestamp rows inserted.}
#'   \item{`n_na_before`}{Total NA cells before gap-filling.}
#'   \item{`n_na_after`}{Total NA cells after gap-filling
#'     (includes inserted rows).}
#'   \item{`gap_timestamps`}{Vector of timestamps that were inserted.}
#'   \item{`time_col`}{Name of the timestamp column.}
#'   \item{`freq`}{Frequency string describing the step used.}
#'   \item{`n_snapped`}{Number of observed timestamps snapped onto the grid
#'     (`0` for calendar units or when `tolerance = 0`).}
#'   \item{`n_dropped_duplicate`}{Rows dropped because a closer observation
#'     already claimed the same grid slot.}
#'   \item{`n_dropped_tolerance`}{Rows dropped because they were too far
#'     from any grid slot.}
#' }
#'
#' @examples
#' # Sensor drift: 13:06 should have been 13:05
#' df <- data.frame(
#'   datetime = as.POSIXct(c("2024-01-01 13:00:00",
#'                            "2024-01-01 13:06:00",
#'                            "2024-01-01 13:10:00")),
#'   vpd = c(1.2, 1.4, 1.5)
#' )
#' result <- fill_time_gaps(df, time_col = "datetime", n = 5, unit = "min")
#' result$data
#'
#' # Monthly data - missing February (calendar unit: exact match only)
#' df_m <- data.frame(
#'   date  = as.Date(c("2024-01-01", "2024-03-01", "2024-04-01")),
#'   sales = c(100, 130, 150)
#' )
#' result_m <- fill_time_gaps(df_m, time_col = "date", n = 1, unit = "month")
#'
#' @export
fill_time_gaps <- function(data,
                           time_col,
                           n    = 1,
                           unit = c("sec", "min", "hour", "day",
                                    "month", "quarter", "year"),
                           tolerance = NULL,
                           verbose = TRUE) {

  # -- Auto-convert tsibble / tibble -> data.frame ---------------------------
  # tsibble does not support rbind() and must be converted before gap insertion
  if (inherits(data, "tbl_ts")) {
    if (verbose)
      message("[INFO] tsibble detected -> converting to data.frame automatically.")
    data <- as.data.frame(data)
  } else if (inherits(data, c("tbl_df", "tbl"))) {
    data <- as.data.frame(data)
  }

  .check_df(data)
  unit <- match.arg(unit)

  if (!time_col %in% names(data))
    rlang::abort(sprintf("`time_col` '%s' not found in data.", time_col))

  if (!is.numeric(n) || n <= 0)
    rlang::abort("`n` must be a positive number.")

  ts <- data[[time_col]]

  # -- Validate timestamp class ----------------------------------------------
  if (!inherits(ts, c("Date", "POSIXct", "POSIXlt"))) {
    rlang::abort(sprintf(paste0(
      "Column '%s' must be Date or POSIXct/POSIXlt, not %s.\n",
      "  Use combine_datetime() first, or:\n",
      "  data$%s <- as.POSIXct(data$%s)"
    ), time_col, class(ts)[1], time_col, time_col))
  }

  # -- month/quarter require Date (not POSIXct) ------------------------------
  if (unit %in% c("month", "quarter") && !inherits(ts, "Date")) {
    rlang::abort(paste0(
      "unit = '", unit, "' requires a Date column, not POSIXct.\n",
      "  Convert first: data$", time_col, " <- as.Date(data$", time_col, ")"
    ))
  }

  # -- Only sec/min/hour/day have a fixed duration -> only these can snap ----
  is_calendar   <- unit %in% c("month", "quarter")
  snap_capable  <- unit %in% c("sec", "min", "hour", "day")

  if (!snap_capable && !is.null(tolerance) && tolerance != 0) {
    warning(sprintf(
      "`tolerance` is ignored for unit = '%s' (no fixed duration); using exact matching.",
      unit
    ), call. = FALSE)
  }

  do_snap <- snap_capable && (is.null(tolerance) || tolerance != 0)

  val_cols    <- setdiff(names(data), time_col)
  n_na_before <- sum(is.na(data[, val_cols, drop = FALSE]))

  n_snapped           <- 0L
  n_dropped_duplicate <- 0L
  n_dropped_tolerance <- 0L

  # ===========================================================================
  # PATH A: calendar units (month/quarter) or year, or snapping disabled
  #         -> legacy exact-match behavior, unchanged
  # ===========================================================================
  if (is_calendar || unit == "year" || !do_snap) {

    if (is_calendar) {
      months_per_step <- if (unit == "quarter") as.integer(n) * 3L else as.integer(n)
      full_seq <- seq.Date(
        from = min(ts, na.rm = TRUE),
        to   = max(ts, na.rm = TRUE),
        by   = paste(months_per_step, "months")
      )
      freq_str <- if (unit == "quarter") {
        sprintf("every %g quarter(s) [%d months]", n, months_per_step)
      } else {
        sprintf("every %g month(s)", n)
      }
    } else {
      freq_str <- paste(n, switch(unit,
                                  sec  = "secs",
                                  min  = "mins",
                                  hour = "hours",
                                  day  = "days",
                                  year = "years"
      ))
      full_seq <- seq(
        from = min(ts, na.rm = TRUE),
        to   = max(ts, na.rm = TRUE),
        by   = freq_str
      )
    }

    existing_num   <- as.numeric(ts)
    full_seq_num   <- as.numeric(full_seq)
    missing_num    <- setdiff(full_seq_num, existing_num)
    gap_timestamps <- full_seq[full_seq_num %in% missing_num]
    n_gaps         <- length(gap_timestamps)

    if (n_gaps > 0) {
      gap_df <- .build_na_rows(data, val_cols, gap_timestamps, time_col)
      data_full           <- rbind(data, gap_df)
      data_full           <- data_full[order(data_full[[time_col]]), ]
      rownames(data_full) <- NULL
    } else {
      data_full <- data
    }

  } else {

    # ===========================================================================
    # PATH B: sec/min/hour/day -> snap-to-grid, then fill remaining gaps
    # ===========================================================================

    unit_sec <- switch(unit, sec = 1, min = 60, hour = 3600, day = 86400)
    step_sec <- n * unit_sec
    tol_sec  <- if (is.null(tolerance)) step_sec / 2 else tolerance

    if (tol_sec > step_sec / 2 + 1e-8) {
      warning(
        "`tolerance` is larger than half the step size; two observations ",
        "could tie for the same grid slot. Consider tolerance <= n*unit / 2.",
        call. = FALSE
      )
    }

    freq_str <- paste(n, switch(unit, sec = "secs", min = "mins",
                                hour = "hours", day = "days"))
    full_seq <- seq(
      from = min(ts, na.rm = TRUE),
      to   = max(ts, na.rm = TRUE),
      by   = freq_str
    )

    # -- Date columns store as.numeric() in *days*, POSIXct in *seconds*.
    #    step_sec/tol_sec above are always in seconds, so do all snap
    #    arithmetic in a common seconds-based representation, then convert
    #    the result back to the timestamp's original class at the end.
    ts_is_date <- inherits(ts, "Date")
    ts_tzone   <- attr(ts, "tzone")
    ts_seconds       <- if (ts_is_date) as.POSIXct(ts, tz = "UTC") else ts
    full_seq_seconds <- if (ts_is_date) as.POSIXct(full_seq, tz = "UTC") else full_seq

    full_seq_num <- as.numeric(full_seq_seconds)
    origin_num   <- full_seq_num[1]

    ts_num   <- as.numeric(ts_seconds)
    grid_idx <- round((ts_num - origin_num) / step_sec)
    grid_idx <- pmin(pmax(grid_idx, 0L), length(full_seq) - 1L)  # clamp edge rounding

    snapped_num <- origin_num + grid_idx * step_sec
    diff_sec    <- abs(ts_num - snapped_num)
    within_tol  <- !is.na(diff_sec) & diff_sec <= tol_sec

    work <- data
    work$.grid_idx   <- grid_idx
    work$.diff_sec   <- diff_sec
    work$.within_tol <- within_tol

    ord    <- order(work$.grid_idx, work$.diff_sec, na.last = TRUE)
    work   <- work[ord, ]
    is_dup <- duplicated(work$.grid_idx)

    n_dropped_duplicate <- sum(is_dup & work$.within_tol, na.rm = TRUE)
    n_dropped_tolerance <- sum(!work$.within_tol & !is_dup, na.rm = TRUE)

    keep         <- work$.within_tol & !is_dup
    matched      <- work[keep, val_cols, drop = FALSE]
    snapped_secs <- origin_num + work$.grid_idx[keep] * step_sec

    matched[[time_col]] <- if (ts_is_date) {
      as.Date(as.POSIXct(snapped_secs, origin = "1970-01-01", tz = "UTC"))
    } else {
      as.POSIXct(snapped_secs, origin = "1970-01-01",
                 tz = if (is.null(ts_tzone) || ts_tzone == "") "" else ts_tzone)
    }

    n_snapped <- sum(work$.diff_sec[keep] > 0, na.rm = TRUE)  # rows actually moved

    matched_idx    <- work$.grid_idx[keep]
    missing_idx    <- setdiff(seq_len(length(full_seq)) - 1L, matched_idx)
    gap_timestamps <- full_seq[missing_idx + 1L]
    n_gaps         <- length(gap_timestamps)

    if (n_gaps > 0) {
      gap_df    <- .build_na_rows(data, val_cols, gap_timestamps, time_col)
      data_full <- rbind(matched[, names(data), drop = FALSE], gap_df)
    } else {
      data_full <- matched[, names(data), drop = FALSE]
    }
    data_full           <- data_full[order(data_full[[time_col]]), ]
    rownames(data_full) <- NULL
  }

  n_na_after <- sum(is.na(data_full[, val_cols, drop = FALSE]))

  # -- Console output ----------------------------------------------------------
  if (verbose) {
    unit_label <- switch(unit,
                         sec     = "second(s)",
                         min     = "minute(s)",
                         hour    = "hour(s)",
                         day     = "day(s)",
                         month   = "month(s)",
                         quarter = "quarter(s)",
                         year    = "year(s)"
    )

    .header("STEP : Check and Fill Missing Timestamps")
    cat(sprintf("  Frequency  : every %g %s\n", n, unit_label))
    if (unit == "quarter")
      cat(sprintf("  (1 quarter = 3 months)\n"))
    if (do_snap)
      cat(sprintf("  Tolerance  : +/- %.0f sec\n", tol_sec))
    cat(sprintf("  Expected   : %d rows\n", length(full_seq)))
    cat(sprintf("  Found      : %d rows\n", nrow(data)))
    cat(sprintf("  Gaps       : %d rows inserted\n", n_gaps))
    if (do_snap) {
      cat(sprintf("  Snapped    : %d timestamp(s) moved onto the grid\n", n_snapped))
      cat(sprintf("  Dropped    : %d duplicate(s), %d out-of-tolerance\n",
                  n_dropped_duplicate, n_dropped_tolerance))
    }
    cat("\n")

    na_from_gaps <- n_gaps * length(val_cols)
    na_preexist  <- n_na_before
    cat(sprintf("  NA before  : %d\n", n_na_before))
    cat(sprintf("  NA after   : %d\n", n_na_after))
    if (n_gaps > 0) {
      cat(sprintf("    \u2514\u2500 inserted rows  : %d x %d cols = %d  (filled in next step)\n",
                  n_gaps, length(val_cols), na_from_gaps))
      cat(sprintf("    \u2514\u2500 pre-existing   : %d\n", na_preexist))
    }
    cat("\n")

    if (n_gaps > 0) {
      show_n <- min(10L, n_gaps)
      .subheader(sprintf("Inserted timestamps (%d of %d)", show_n, n_gaps))
      print(utils::head(gap_timestamps, show_n))
      if (n_gaps > show_n)
        cat(sprintf("  ... and %d more\n", n_gaps - show_n))
      cat("\n  >> Next: ts_preprocess(gap$data, ...)\n\n")
    } else {
      cat("  [OK] No gaps found\n\n")
      cat("  >> Next: ts_preprocess()\n\n")
    }
  }

  invisible(list(
    data                = data_full,
    n_gaps              = n_gaps,
    n_na_before         = n_na_before,
    n_na_after          = n_na_after,
    gap_timestamps      = gap_timestamps,
    time_col            = time_col,
    freq                = freq_str,
    n_snapped           = n_snapped,
    n_dropped_duplicate = n_dropped_duplicate,
    n_dropped_tolerance = n_dropped_tolerance
  ))
}

#' Build NA-filled rows for a set of timestamps, preserving column types
#' @keywords internal
#' @noRd
.build_na_rows <- function(data, val_cols, timestamps, time_col) {
  n_rows <- length(timestamps)
  gap_df <- as.data.frame(
    lapply(val_cols, function(col) {
      x <- data[[col]]
      if (is.integer(x))   return(rep(NA_integer_,  n_rows))
      if (is.numeric(x))   return(rep(NA_real_,     n_rows))
      if (is.character(x)) return(rep(NA_character_, n_rows))
      if (is.logical(x))   return(rep(NA,            n_rows))
      if (is.factor(x))    return(factor(rep(NA, n_rows), levels = levels(x)))
      rep(NA, n_rows)
    }),
    stringsAsFactors = FALSE
  )
  names(gap_df) <- val_cols
  gap_df[[time_col]] <- timestamps
  gap_df[, names(data), drop = FALSE]
}
