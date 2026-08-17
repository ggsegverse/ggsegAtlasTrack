# Build the AtlasTrack tract-core label volume from the probabilistic maps.
#
# The distributed AtlasTrack_labels.nii.gz is a winner-take-all projection of
# the probabilistic tract maps, so overlapping tracts lose territory to their
# own subdivisions (R_SLF keeps only 26% of its own high-probability core, the
# rest is claimed by R_pSLF) and every tract is dilated far beyond its core.
# Rendering that volume paints whole lobes rather than tracts.
#
# This script rebuilds the label volume from fiber_atlas/*_mean_countatlas.mat,
# thresholding each tract at a fraction of its own maximum probability so each
# tract is reduced to its dense core, then merging with highest-probability-wins.
#
# Data source: the AtlasTrack distribution from NITRC
# (https://www.nitrc.org/projects/atlastrack), which ships fiber_atlas/ (the
# per-tract probabilistic maps read here), T1_Atlas/ (the template the labels
# are defined in) and documentation/. Roughly 725 MB unzipped.
#
# Volumes are not version-controlled (see .gitignore), so this script and the
# steps below are the record of how data-raw/source/ is produced. Point
# ATLASTRACK_DIR at the unzipped folder and run:
#
#   Rscript data-raw/build-tract-cores.R      # -> AtlasTrack_tract_cores.nii.gz
#
# create-atlas.R additionally needs AtlasTrack_T1_brain.mgz, the brain-masked
# template used for registration, made once from the same distribution with:
#
#   mri_mask T1_Atlas/T1_atlas.mgz T1_Atlas/T1_atlas_maskBroad.mgz brain.mgz
#   mri_convert -odt uchar brain.mgz data-raw/source/AtlasTrack_T1_brain.mgz
#
# The resulting registration (registration/atlastrack2fsaverage_t1.lta) *is*
# committed, so create-atlas.R does not re-run it.

library(RNifti)

prob_threshold <- as.numeric(Sys.getenv("ATLASTRACK_THRESHOLD", "0.10"))

atlastrack_dir <- Sys.getenv("ATLASTRACK_DIR", "~/Downloads/AtlasTrack")
fiber_dir <- file.path(path.expand(atlastrack_dir), "fiber_atlas")
if (!dir.exists(fiber_dir)) {
  cli::cli_abort(c(
    "AtlasTrack fiber atlas not found: {.path {fiber_dir}}",
    "i" = "Set {.envvar ATLASTRACK_DIR} to the unzipped AtlasTrack folder."
  ))
}

src_dir <- here::here("data-raw", "source")
reference <- readNifti(file.path(src_dir, "AtlasTrack_labels.nii.gz"))
lut <- read.table(
  file.path(src_dir, "AtlasTrack_LUT.txt"),
  col.names = c("idx", "label", "r", "g", "b", "a")
)

read_tract_prob <- function(idx) {
  path <- file.path(fiber_dir, sprintf("fiber_%d_mean_countatlas.mat", idx))
  if (!file.exists(path)) {
    return(NULL)
  }
  sparse <- R.matlab::readMat(path)$sparse.vol
  volume <- array(0, dim = as.integer(sparse[[3]]))
  volume[as.integer(sparse[[1]])] <- as.numeric(sparse[[2]])
  volume
}

merged <- array(0L, dim = dim(reference))
best_prob <- array(0, dim = dim(reference))
kept <- list()

for (i in seq_len(nrow(lut))) {
  prob <- read_tract_prob(lut$idx[i])
  if (is.null(prob)) {
    next
  }
  core <- prob >= prob_threshold * max(prob)
  wins <- core & prob > best_prob
  merged[wins] <- as.integer(lut$idx[i])
  best_prob[wins] <- prob[wins]
  kept[[length(kept) + 1L]] <- data.frame(
    idx = lut$idx[i],
    label = lut$label[i],
    core = sum(core),
    retained = sum(merged == lut$idx[i])
  )
  cli::cli_alert_info(
    "{lut$label[i]}: core {sum(core)} voxels, retained {sum(merged == lut$idx[i])}"
  )
}

kept <- do.call(rbind, kept)
lost <- kept[kept$retained < 0.25 * kept$core, ]
if (nrow(lost) > 0) {
  cli::cli_warn(c(
    "Tracts losing >75% of their core to overlap:",
    stats::setNames(
      sprintf("%s (%d of %d)", lost$label, lost$retained, lost$core),
      rep("!", nrow(lost))
    )
  ))
}

out <- reference
out[] <- merged
writeNifti(
  out,
  file.path(src_dir, "AtlasTrack_tract_cores.nii.gz"),
  datatype = "int16"
)

cli::cli_alert_success(
  "Wrote {sum(merged > 0)} labelled voxels across {length(unique(merged[merged > 0]))} tracts \\
   (threshold {prob_threshold}) to {.path AtlasTrack_tract_cores.nii.gz}"
)
