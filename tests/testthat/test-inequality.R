test_that("inequality", {
  SLID <- carData::SLID |>
    tibble::as_tibble() |>
    dplyr::filter(!is.na(wages))

  SLID_agg <- SLID |>
    dplyr::mutate(wageclass = cut(wages, 20)) |>
    dplyr::group_by(sex, wageclass) |>
    dplyr::summarise(pop = dplyr::n(),
                     wages = mean(wages),
                     .groups = "drop")

  out <- SLID |>
    inequality(wages,
               index = c("gini", "theil"))
  expect_s3_class(out, "inequality")

  out <- SLID_agg |>
    inequality(wages, pop,
               index = c("mld", "theil"))
  expect_s3_class(out, "inequality")

  out <- SLID |>
    dplyr::group_by(sex) |>
    inequality(wages)
  expect_s3_class(out, "inequality")
  expect_true("sex" %in% names(out))

  out <- SLID_agg |>
    dplyr::group_by(sex) |>
    inequality(wages, pop)
  expect_s3_class(out, "inequality")
  expect_true("sex" %in% names(out))
})
