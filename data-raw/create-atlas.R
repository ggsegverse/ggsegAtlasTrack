# Create AtlasTrack fiber tract atlas for the ggseg ecosystem
#
# AtlasTrack probabilistic white matter fiber tract atlas from the ABCD study.
#
# Source: ABCD Study / DEAP (https://deap.nimhda.org/)
#
# Reference: Hagler DJ Jr, et al. (2019). "Image processing and analysis
#   methods for the Adolescent Brain Cognitive Development Study." NeuroImage,
#   202:116091. DOI: 10.1016/j.neuroimage.2019.116091
#
# Requirements:
#   - ggseg.extra, ggseg.formats
#
# Run with: Rscript data-raw/create-atlas.R

library(dplyr)
library(ggseg.extra)
library(ggseg.formats)

options(chromote.timeout = 120)
future::plan(future::sequential)
progressr::handlers("cli")
progressr::handlers(global = TRUE)

# ── Obtain tract probability maps ──────────────────────────────
# AtlasTrack provides probabilistic white matter tract maps as NIfTI volumes.
# Obtain the atlas volume from the ABCD study resources.
#
# Place the NIfTI volume in data-raw/:

vol_dir <- here::here("data-raw")
vol_file <- file.path(vol_dir, "AtlasTrack_tracts.nii.gz")

if (!file.exists(vol_file)) {
  cli::cli_abort(c(
    "Volume file not found: {.path {vol_file}}",
    "i" = "Obtain AtlasTrack from ABCD study resources",
    "i" = "Place as: {.path {vol_file}}"
  ))
}

# ── Create atlas from volume ─────────────────────────────────────
cli::cli_h1("Creating AtlasTrack fiber tract atlas")

atlastrack <- create_subcortical_from_volume(
  input_volume = vol_file,
  atlas_name = "atlastrack",
  output_dir = vol_dir,
  skip_existing = TRUE,
  cleanup = FALSE
)

atlastrack <- atlastrack |>
  atlas_region_contextual("unknown|Background", "label")

cli::cli_alert_success("atlastrack: {nrow(atlastrack$core)} tracts")
print(atlastrack)

# ── Save atlas data ──────────────────────────────────────────────
brain_pals <- stats::setNames(
  list(atlastrack$palette),
  atlastrack$atlas
)
save(brain_pals, file = here::here("R/sysdata.rda"), compress = "xz")

usethis::use_data(atlastrack, overwrite = TRUE, compress = "xz")
cli::cli_alert_success("Saved to data/atlastrack.rda")
