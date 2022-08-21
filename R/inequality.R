#' Inequality
#'
#' @param data A (grouped) data frame.
#' @param value A variable to measure inequality.
#' @param weight A variable of weights. By default, no weighting.
#' @param index Inequality indices to be measured (`"gini"`, `"mld"`, `"polar"`,
#' or `"theil"`). By default, `"gini"`.
#'
#' @return A tibble with class `inequality` having columns grouping variables,
#' `.index`, `inequality`, `.cumulative`.
#'
#' @export
inequality <- function(data, value,
                       weight = NULL,
                       index = "gini") {
  index <- arg_match(index, c("gini", "mld", "polar", "theil"),
                     multiple = TRUE)

  nms <- names2(data)
  value <- tidyselect::vars_pull(nms, {{ value }})

  if (quo_is_null(enquo(weight))) {
    weight <- NULL
  } else {
    weight <- tidyselect::vars_pull(nms, {{ weight }})
  }

  if (is_null(weight)) {
    data <- data |>
      dplyr::rename(.value = !!value) |>
      dplyr::select(dplyr::group_cols(), ".value") |>
      tibble::add_column(.weight = 1)
  } else {
    data <- data |>
      dplyr::rename(.value = !!value,
                    .weight = !!weight) |>
      dplyr::select(dplyr::group_cols(), ".value", ".weight")
  }

  out <- data |>
    dplyr::mutate(dplyr::across(c(".value", ".weight"),
                                purrr::partial(vec_cast,
                                               to = double()))) |>
    dplyr::group_nest(.key = ".inequality") |>
    tidyr::expand_grid(.index = index) |>
    dplyr::relocate(!".inequality") |>
    dplyr::mutate(.cumulative = .data$.inequality |>
                    purrr::modify(function(inequality) {
                      inequality |>
                        dplyr::arrange(dplyr::across(".value")) |>
                        dplyr::mutate(.value = cumsum(.data$.value * .data$.weight / sum(.data$.value * .data$.weight)),
                                      .weight = cumsum(.data$.weight) / sum(.data$.weight)) |>
                        tibble::add_row(.value = 0,
                                        .weight = 0,
                                        .before = 1)
                    }),
                  .inequality = list(.data$.index, .data$.inequality) |>
                    purrr::pmap_dbl(function(index, inequality) {
                      value <- inequality$.value
                      weight <- inequality$.weight

                      switch(
                        index,
                        gini = dineq::gini.wtd(value, weight),
                        mld = dineq::mld.wtd(value, weight),
                        polar = dineq::polar.wtd(value, weight),
                        theil = dineq::theil.wtd(value, weight)
                      )
                    }))
  class(out) <- c("inequality", class(out))
  out
}

#' @export
autoplot.inequality <- function(object,
                                mapping = NULL,
                                line = TRUE, ...) {
  data <- object |>
    dplyr::select(!c(".index", ".inequality"))
  data <- vec_slice(data, vec_unique_loc(data))

  if (is_null(mapping)) {
    nms <- setdiff(names2(data), ".cumulative")

    if (vec_is_empty(nms)) {
      mapping <- aes(.data$.weight, .data$.value)
    } else {
      col <- paste(nms,
                   collapse = "_")
      data <- data |>
        tidyr::unite(!!col, !".cumulative")
      mapping <- aes(.data$.weight, .data$.value,
                     color = !!parse_expr(col),
                     fill = !!parse_expr(col))
    }
  }

  data <- data |>
    tidyr::unnest(".cumulative")

  out <- ggplot2::ggplot(data, mapping)

  if (line) {
    out <- out +
      ggplot2::geom_line(...)
  }
  out
}

# gini <- function(x, y) {
#   order <- vec_order(y)
#   x <- vec_slice(x, order)
#   y <- vec_slice(y, order)
#
#   x <- x / sum(x)
#   y <- x * y / sum(x * y)
#
#   sum((2 * cumsum(x) - x - sum(x)) * y)
# }
