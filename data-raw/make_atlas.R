# Create AtlasTrack Fiber Tract Atlas
#
# AtlasTrack ships as a maximum-probability NIfTI *label volume* of white-matter
# fiber tracts (not streamlines). We build a proper tract atlas with
# ggseg.extra::create_tract_from_volume(): each tract's voxel cloud is reduced to
# a principal-curve centerline, then rendered as a 3D tube and a 2D projection on
# a grey-brain (fsaverage) context — matching the FreeSurfer/tracula tract look.
#
# Source: https://www.nitrc.org/projects/atlastrack
#   The source .mat files were converted to a maximum-probability NIfTI label
#   volume (AtlasTrack is in FreeSurfer conformed / fsaverage space).
# Reference: AtlasTrack probabilistic white-matter fiber tract atlas.
#
# Requires: ggseg.extra, ggseg.formats, princurve, FreeSurfer 7.4.1 (fsaverage).
#
# Run with: Rscript data-raw/make_atlas.R

library(ggseg.extra)
library(ggseg.formats)

fs_home <- Sys.getenv("FREESURFER_HOME", "/Applications/freesurfer/7.4.1")
aseg <- file.path(fs_home, "subjects", "fsaverage", "mri", "aseg.mgz")

# Exclude the aggregate whole-brain fibre masks (AllFib*, 2000-2004) and the
# "cut" fornix variants (Fxcut, 1014/1024); the optic radiation labels are empty
# in this volume and drop out automatically.
atlastrack <- create_tract_from_volume(
  input_volume = here::here("data-raw", "source", "AtlasTrack_labels.nii.gz"),
  input_lut = here::here("data-raw", "source", "AtlasTrack_LUT.txt"),
  input_aseg = aseg,
  exclude = c(2000, 2001, 2002, 2003, 2004, 1014, 1024),
  atlas_name = "atlastrack",
  output_dir = "data-raw",
  tube_radius = 3,
  cleanup = FALSE
)

print(atlastrack)

.atlastrack <- atlastrack
usethis::use_data(
  .atlastrack,
  overwrite = TRUE,
  compress = "xz",
  internal = TRUE
)
