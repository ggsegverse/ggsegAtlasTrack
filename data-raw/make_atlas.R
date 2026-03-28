# Create AtlasTrack Fiber Tract Atlas
#
# Source: https://www.nitrc.org/projects/atlastrack
# Download: https://www.nitrc.org/frs/?group_id=1337
#   - Place AtlasTrack_tracts.nii.gz in data-raw/source/
#
# Date obtained: [FILL IN WHEN DOWNLOADED]
#
# Run with: Rscript data-raw/make_atlas.R

library(ggseg.extra)
library(ggseg.formats)

atlastrack <- create_subcortical_from_volume(
  input_volume = here::here("data-raw", "source", "AtlasTrack_tracts.nii.gz"),
  atlas_name = "atlastrack",
  output_dir = "data-raw",
  skip_existing = TRUE,
  cleanup = FALSE
)

print(atlastrack)
plot(atlastrack)

.atlastrack <- atlastrack
usethis::use_data(.atlastrack, overwrite = TRUE, compress = "xz", internal = TRUE)
