describe("atlastrack atlas structure", {
  it("is a valid ggseg_atlas object", {
    expect_s3_class(atlastrack(), "ggseg_atlas")
  })

  it("has required core columns", {
    required_cols <- c("hemi", "region", "label")
    expect_true(all(required_cols %in% names(atlastrack()$core)))
  })

  it("has valid hemisphere values", {
    valid_hemis <- c("left", "right")
    hemis <- unique(atlastrack()$core$hemi)
    hemis <- hemis[!is.na(hemis)]
    expect_true(all(hemis %in% valid_hemis))
  })

  it("has atlas name and type", {
    expect_true(nchar(atlastrack()$atlas) > 0)
    expect_true(atlastrack()$type %in% c("cortical", "subcortical", "tract"))
  })

  it("has non-empty core", {
    expect_true(nrow(atlastrack()$core) > 0)
  })
})


describe("atlastrack 3D rendering support", {
  it("has vertex data for 3D rendering", {
    expect_true(!is.null(atlastrack()$data) || !is.null(atlastrack()$data$vertices))
  })
})


describe("atlastrack 2D plotting", {
  it("can be plotted with ggseg", {
    skip_if_not_installed("ggseg")

    p <- ggplot2::ggplot() + ggseg::geom_brain(atlas = atlastrack())
    expect_s3_class(p, c("gg", "ggplot"))
  })

  it("can be plotted with region fill", {
    skip_if_not_installed("ggseg")
    skip_if_not_installed("ggplot2")

    p <- ggplot2::ggplot() +
      ggseg::geom_brain(
        atlas = atlastrack(),
        mapping = ggplot2::aes(fill = region)
      )
    expect_s3_class(p, c("gg", "ggplot"))
  })
})


describe("atlastrack 3D plotting", {
  it("can be rendered with ggseg3d", {
    skip_if_not_installed("ggseg3d")
    skip_on_ci()

    p <- ggseg3d::ggseg3d(atlas = atlastrack())
    expect_s3_class(p, "htmlwidget")
  })
})


describe("atlastrack data quality", {
  it("has unique labels per hemisphere", {
    labels_by_hemi <- split(atlastrack()$core$label, atlastrack()$core$hemi)

    for (hemi in names(labels_by_hemi)) {
      labels <- labels_by_hemi[[hemi]]
      labels <- labels[!is.na(labels)]
      expect_equal(
        length(labels),
        length(unique(labels)),
        info = paste("Duplicate labels in", hemi, "hemisphere")
      )
    }
  })

  it("has no empty region names (except NA for wall/unknown)", {
    regions <- atlastrack()$core$region
    non_na_regions <- regions[!is.na(regions)]
    expect_true(all(nchar(non_na_regions) > 0))
  })

  it("has valid hex colours", {
    colours <- atlastrack()$core$colour
    non_na_colours <- colours[!is.na(colours)]

    if (length(non_na_colours) > 0) {
      is_valid <- vapply(non_na_colours, function(col) {
        grepl("^#[0-9A-Fa-f]{6}$|^#[0-9A-Fa-f]{8}$", col) ||
        col %in% grDevices::colours()
      }, logical(1))
      expect_true(all(is_valid))
    }
  })
})
