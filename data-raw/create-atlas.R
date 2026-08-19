# Create AtlasTrack fiber tract atlas for the ggseg ecosystem
#
# AtlasTrack probabilistic white-matter fiber tract atlas from the ABCD study.
#
# Each tract is built from its probabilistic map rather than the distributed
# winner-take-all label volume -- see data-raw/build-tract-cores.R, which writes
# AtlasTrack_tract_cores.nii.gz. AtlasTrack lives in its own template space,
# pitched ~24 degrees and offset from fsaverage, so the tract cores are
# affine-registered through the atlas T1 (a straight intensity T1 -> T1
# alignment against fsaverage) and resampled into fsaverage space.
#
# Each tract is then reduced to a principal-curve centerline and built into a
# proper tract atlas (type = "tract") with create_tract_from_volume(): a 3D
# tube per tract, and a 2D projection over the grey fsaverage silhouette.
#
# Source: AtlasTrack, distributed via NITRC
#   (https://www.nitrc.org/projects/atlastrack). The source volumes are not
#   version-controlled; see data-raw/build-tract-cores.R for how the files in
#   data-raw/source/ are produced from that distribution.
# Reference: Hagler DJ Jr, et al. (2019). "Image processing and analysis
#   methods for the Adolescent Brain Cognitive Development Study." NeuroImage,
#   202:116091. DOI: 10.1016/j.neuroimage.2019.116091
#
# Requires: ggseg.extra, ggseg.formats, RNifti, FreeSurfer 7.4.1 with fsaverage.
#
# Run with: Rscript data-raw/create-atlas.R

library(dplyr)
library(ggseg.extra)
library(ggseg.formats)

future::plan(future::sequential)
progressr::handlers("cli")
progressr::handlers(global = TRUE)

data_raw <- here::here("data-raw")
src_dir <- file.path(data_raw, "source")
vol_file <- file.path(src_dir, "AtlasTrack_tract_cores.nii.gz")
t1_file <- file.path(src_dir, "AtlasTrack_T1_brain.mgz")
lut_file <- file.path(src_dir, "AtlasTrack_LUT.txt")
stopifnot(
  "AtlasTrack_tract_cores.nii.gz not found; run data-raw/build-tract-cores.R" = file.exists(
    vol_file
  ),
  "AtlasTrack_T1_brain.mgz not found" = file.exists(t1_file),
  "AtlasTrack_LUT.txt not found" = file.exists(lut_file)
)

fs_home <- Sys.getenv("FREESURFER_HOME", "/Applications/freesurfer/7.4.1")
fsavg_mri <- file.path(fs_home, "subjects", "fsaverage", "mri")
aseg_mgz <- file.path(fsavg_mri, "aseg.mgz")

# ── Tract colour table (named tracts only) ───────────────────────────────
# Drop the aggregate whole-brain fibre masks (AllFib*, 2000-2004), the fornix
# cut labels (Fxcut, 1014/1024) and the empty optic radiation (OR, 139/140).
#
# CC (123) is dropped for the same reason as the AllFib* masks: it is an
# aggregate rather than a tract. Its forceps are already present as their own
# labels and sit almost entirely inside it (Fmaj 96%, Fmin 88%), so it draws
# the same fibres twice. It is also a sheet, not a bundle, and a single
# principal curve through it wanders diagonally across both hemispheres rather
# than following any real pathway.
lut <- read_lut(lut_file)
drop_ids <- c(2000:2004, 1014, 1024, 139, 140, 123)
tract_lut <- lut[!(as.integer(lut$idx) %in% drop_ids), , drop = FALSE]
cli::cli_alert_info("Named tracts: {nrow(tract_lut)}")

# ── Affine-register AtlasTrack to fsaverage via the atlas T1 ─────────────
# AtlasTrack_T1_brain.mgz is the brain-masked template the labels are defined
# in (identical 256^3 geometry), so this is a plain intensity T1 -> T1
# alignment rather than an inference from the tract extent itself.
# Nearest-neighbour resampling is applied later by project_volume_anatomical()
# when it pushes each label through this LTA.
reg_dir <- file.path(data_raw, "registration")
dir.create(reg_dir, showWarnings = FALSE)

cli::cli_h1("Registering AtlasTrack T1 to fsaverage")

reg_lta <- file.path(reg_dir, "atlastrack2fsaverage_t1.lta")
if (file.exists(reg_lta)) {
  cli::cli_alert_info("Reusing registration: {.path {reg_lta}}")
} else {
  reg_status <- system2(
    file.path(fs_home, "bin", "mri_robust_register"),
    c(
      "--mov",
      t1_file,
      "--dst",
      file.path(fsavg_mri, "brain.mgz"),
      "--lta",
      reg_lta,
      "--affine",
      "--satit",
      "--iscale"
    )
  )
  if (reg_status != 0 || !file.exists(reg_lta)) {
    cli::cli_abort("mri_robust_register failed (status {reg_status}).")
  }
}

# ── Resample the tract cores into fsaverage space ────────────────────────
# create_tract_from_volume() expects the label volume and the anatomical
# reference to share a space, so the cores are pushed through the registration
# with nearest-neighbour interpolation (a label volume must not be averaged).
cli::cli_h1("Resampling tract cores into fsaverage")
cores_fsavg <- file.path(reg_dir, "tract_cores_in_fsaverage.nii.gz")
if (!file.exists(cores_fsavg)) {
  vol2vol_status <- system2(
    file.path(fs_home, "bin", "mri_vol2vol"),
    c(
      "--mov",
      vol_file,
      "--targ",
      aseg_mgz,
      "--lta",
      reg_lta,
      "--nearest",
      "--o",
      cores_fsavg
    )
  )
  if (vol2vol_status != 0 || !file.exists(cores_fsavg)) {
    cli::cli_abort("mri_vol2vol failed (status {vol2vol_status}).")
  }
}

# ── Projection slabs at fixed anatomical positions ───────────────────────
# Slice positions are specified in RAS millimetres so they are anatomically
# meaningful and independent of the template's voxel grid. Each slab spans
# +/- slab_halfwidth slices around its midpoint.
slab_halfwidth <- 8L
slice_mm <- data.frame(
  name = c(
    "superior_axial",
    "mid_axial",
    "inferior_axial",
    "coronal",
    "sagittal"
  ),
  type = c("axial", "axial", "axial", "coronal", "sagittal"),
  mm = c(17, 2, -11, -17, -12),
  stringsAsFactors = FALSE
)

# RAS millimetres -> index along the corresponding axis of the RAS+ reoriented
# volume. Derived from the template's own affine rather than hard-coded, so it
# stays correct if the reference volume changes.
ras_mm_to_index <- function(vox2ras, dims, ras_axis, mm) {
  native_axis <- which.max(abs(vox2ras[ras_axis, 1:3]))
  scale <- vox2ras[ras_axis, native_axis]
  native <- (mm - vox2ras[ras_axis, 4]) / scale
  index <- if (scale > 0) native else dims[native_axis] - 1 - native
  as.integer(round(index)) + 1L
}

aseg_vox2ras <- freesurferformats::mghheader.vox2ras(
  freesurferformats::read.fs.mgh(aseg_mgz, with_header = TRUE)$header
)
aseg_dims <- rep(256L, 3L)
ras_axis <- c(axial = 3L, coronal = 2L, sagittal = 1L)

slice_mm$mid <- mapply(
  function(type, mm) {
    ras_mm_to_index(aseg_vox2ras, aseg_dims, ras_axis[[type]], mm)
  },
  slice_mm$type,
  slice_mm$mm
)

tract_slabs <- data.frame(
  name = slice_mm$name,
  type = slice_mm$type,
  start = slice_mm$mid - slab_halfwidth,
  end = slice_mm$mid + slab_halfwidth,
  stringsAsFactors = FALSE
)
print(tract_slabs)

# ── Fit a centerline per tract and build the tract atlas ─────────────────
# Each tract's voxel cloud is reduced to a principal-curve centerline, drawn
# as a 3D tube and as a 2D projection over the grey fsaverage silhouette that
# input_aseg supplies. Feeding the thresholded cores rather than the
# distributed winner-take-all volume is what makes the curves well
# conditioned: a bloated blob has no meaningful principal axis.
cli::cli_h1("Fitting tract centerlines")
rebuild <- !identical(Sys.getenv("ATLASTRACK_REBUILD", ""), "")
if (rebuild) {
  unlink(file.path(data_raw, "atlastrack"), recursive = TRUE)
}
atlastrack <- create_tract_from_volume(
  input_volume = cores_fsavg,
  input_lut = tract_lut,
  input_aseg = aseg_mgz,
  atlas_name = "atlastrack",
  output_dir = data_raw,
  slabs = tract_slabs,
  skip_existing = !rebuild,
  cleanup = FALSE
)

stopifnot(
  "atlastrack must be a tract atlas" = is_tract_atlas(atlastrack)
)

# Views come back alphabetically; order them superior -> inferior, then the
# other planes, so the panels read anatomically.
atlastrack <- atlas_view_reorder(atlastrack, slice_mm$name)

# Cache the unsmoothed atlas so smoothing can be retuned without rebuilding.
saveRDS(atlastrack, file.path(data_raw, "atlastrack_unsmoothed.rds"))

# ── Smooth and simplify ──────────────────────────────────────────────────
# Post-hoc, so retuning never means rerunning the pipeline. Smooth first, then
# simplify: smoothing interpolates vertices, so simplifying first would just
# have its saving undone. The cortex keeps more of its vertices than the
# tracts -- its gyral ribbon is real anatomy, whereas a tract is an idealised
# centerline tube that loses nothing by being drawn smoothly.
# Volumetric projection leaves stray specks detached from their tract; those
# are dropped first, since smoothing them would only make them tidier. The
# cortex is spared: a thin ribbon's gyral cross-sections are legitimately small
# pieces, not specks, and removing them strips its detail.
#
# The two structures want different smoothing. Tracts are solid centerline
# tubes with no holes to lose, so the default morphological closing rounds them
# freely. The cortex is a thin ribbon whose sulci are enclosed holes, and
# closing fills any hole narrower than the smoothing distance -- so it gets
# "ksmooth", which low-pass filters the outline without dilating it. Chaikin
# also preserves holes but converges after two refinements, so it cannot be
# pushed as far.
atlastrack <- atlastrack |>
  atlas_view_remove_small(
    min_area = 20,
    scope = "piece",
    exclude = "^cortex"
  ) |>
  atlas_smooth(
    keep = 1,
    smoothness = 0.8,
    method = "close",
    exclude = "^cortex"
  ) |>
  atlas_smooth(
    keep = 1,
    smoothness = 0.6,
    method = "ksmooth",
    labels = "^cortex"
  ) |>
  atlas_smooth(keep = 0.4, labels = "^cortex") |>
  atlas_smooth(keep = 0.2, exclude = "^cortex")

# ── Choose which tracts each view draws ──────────────────────────────────
# Every tract has geometry in most views, which leaves each panel cluttered
# and each tract repeated. A tract is kept only where it is substantially
# represented: in any view holding at least `view_threshold` of the area it
# reaches in its best view.
#
# The comparison is made per tract *family* rather than per tract, so left and
# right are shown together -- assigning them independently splits pairs across
# panels, which reads as an error. Sagittal areas are doubled first because it
# cuts one hemisphere while the other views show both; without that it loses
# every family and comes out empty.
view_threshold <- 0.7
lateral_families <- c("SCS", "pSCS", "fSCS", "IFSFC")

view_names <- slice_mm$name
tract_geom <- ggseg.formats:::polygons_unnest(atlas_polygons(atlastrack))
tract_geom <- tract_geom[tract_geom$label %in% atlastrack$core$label, ]
areas <- ggseg.formats:::polygon_geometry_areas(tract_geom)

area_by_view <- tapply(areas$area, list(areas$label, areas$view), sum)
area_by_view <- area_by_view[, view_names, drop = FALSE]
area_by_view[is.na(area_by_view)] <- 0

family <- sub("^[LR]_", "", rownames(area_by_view))
family_area <- rowsum(area_by_view, family)
family_area[, "sagittal"] <- family_area[, "sagittal"] * 2
family_keep <- family_area >= view_threshold * apply(family_area, 1, max)

# Sagittal is a medial plane; the corticostriatal fan and IFSFC are lateral
# projections, shown properly in the coronal and superior axial views.
family_keep[rownames(family_keep) %in% lateral_families, "sagittal"] <- FALSE

keep <- matrix(
  FALSE,
  nrow(area_by_view),
  ncol(area_by_view),
  dimnames = dimnames(area_by_view)
)
for (i in seq_len(nrow(area_by_view))) {
  wanted <- view_names[family_keep[family[i], ] & area_by_view[i, ] > 0]
  # A family's view can hold no geometry for one of its members -- the sagittal
  # plane is left-sided, so right-hemisphere tracts assigned there would vanish.
  if (!length(wanted)) {
    wanted <- view_names[which.max(area_by_view[i, ])]
  }
  keep[i, wanted] <- TRUE
}

# A fallback can leave one hemisphere of a family in a view without its
# partner, which reads as an error in a bilateral view. Complete the pair
# wherever the partner has geometry to show. Sagittal is unaffected: it is a
# left-sided plane, so right-hemisphere tracts have nothing there to add.
for (i in seq_len(nrow(keep))) {
  partner <- chartr("LR", "RL", substr(rownames(keep)[i], 1, 1))
  partner <- paste0(partner, substring(rownames(keep)[i], 2))
  if (!partner %in% rownames(keep)) {
    next
  }
  add <- keep[i, ] & !keep[partner, ] & area_by_view[partner, ] > 0
  keep[partner, add] <- TRUE
}

stopifnot(
  "every tract must be drawn in at least one view" = all(rowSums(keep) > 0)
)

for (tract in rownames(keep)) {
  drop_views <- view_names[!keep[tract, ]]
  if (length(drop_views)) {
    atlastrack <- atlas_view_remove_region(
      atlastrack,
      paste0("^", tract, "$"),
      match_on = "label",
      views = drop_views
    )
  }
}
cli::cli_alert_info(
  "Tracts drawn per view: {paste(view_names, colSums(keep), sep = '=', collapse = ', ')}"
)

cli::cli_alert_success("atlastrack: {nrow(atlastrack$core)} tracts")
print(atlastrack)

# ── Save ─────────────────────────────────────────────────────────────────
.atlastrack <- atlastrack
usethis::use_data(
  .atlastrack,
  overwrite = TRUE,
  compress = "xz",
  internal = TRUE
)
cli::cli_alert_success("Saved atlastrack to R/sysdata.rda")
