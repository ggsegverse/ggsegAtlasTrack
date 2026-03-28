# Create AtlasTrack Fiber Tract Atlas
#
# Source: https://www.nitrc.org/projects/atlastrack
# The source .mat files were converted to a maximum probability NIfTI
# label volume using the fiber count atlases.
#
# Reference: Lippincott Williams & Wilkins. AtlasTrack: A tool for 
#   probabilistic white matter fiber tract atlas-based analysis.
#
# Date obtained: 2026-03-28
#
# Run with: Rscript data-raw/make_atlas.R

library(ggseg.extra)
library(ggseg.formats)

atlastrack <- create_subcortical_from_volume(
  input_volume = here::here("data-raw", "source", "AtlasTrack_labels.nii.gz"),
  input_lut = here::here("data-raw", "source", "AtlasTrack_LUT.txt"),
  atlas_name = "atlastrack",
  output_dir = "data-raw",
  skip_existing = TRUE,
  cleanup = FALSE
)

print(atlastrack)
plot(atlastrack)

.atlastrack <- atlastrack
usethis::use_data(.atlastrack, overwrite = TRUE, compress = "xz", internal = TRUE)
