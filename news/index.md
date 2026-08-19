# Changelog

## ggsegAtlasTrack 2.0.0

- `atlastrack` is rebuilt as a registered, anatomically-contextualised
  atlas, and is now a tract atlas
  ([`atlas_type()`](https://ggsegverse.github.io/ggseg.formats/reference/atlas_type.html)
  returns `"tract"`) carrying a centerline per tract for 3D rendering.

- Tracts are now built from AtlasTrack’s **probabilistic** tract maps
  rather than its distributed label volume. That volume is a
  winner-take-all projection, so every tract was dilated far beyond its
  core and nested subdivisions cannibalised their parents — `R_SLF`
  retained only 26% of its own high-probability core, the rest claimed
  by `R_pSLF`. Rendering it painted whole lobes rather than tracts. Each
  tract is now thresholded at 15% of its own maximum probability and
  merged highest-probability-wins, cutting the labelled volume roughly
  four-fold while keeping all 35 tracts.

- AtlasTrack lives in its own template space, pitched ~24° from
  fsaverage, so the previous release rendered tracts spilling outside
  the brain outline. The tract cores are now affine-registered through
  the AtlasTrack T1 — a direct intensity T1→T1 alignment against
  fsaverage, rather than inferring the transform from the tract extent —
  and resampled into fsaverage space.

- Each tract is reduced to a principal-curve centerline, drawn as a 3D
  tube and as a 2D projection over a grey fsaverage silhouette. Feeding
  the thresholded cores rather than the winner-take-all volume is what
  makes the curve fits well conditioned: a tract dilated across half a
  lobe has no meaningful principal axis.

- 2D projections are taken at five fixed anatomical positions, specified
  in RAS millimetres rather than voxel indices so they stay correct if
  the reference volume changes: axial at +17, +2 and −11 mm, coronal at
  −17 mm and sagittal at −12 mm, each projected over a ±8-slice slab.
  Tracts are projections through the slab; the silhouette framing them
  is a true slice at the midpoint. The sagittal position sits far enough
  laterally to cut the cortex as a gyral ribbon rather than tangentially
  through the medial wall, while staying medial enough to retain the
  brainstem the corticospinal tract descends into (the brainstem does
  not extend past −17 mm). The silhouette includes the brainstem,
  cerebellar cortex and deep grey alongside the cortical ribbon, so
  tracts leaving the cerebrum have anatomical context; white matter is
  left unfilled so the tracts remain visible against it.

- The aggregate whole-brain fibre masks (`AllFib*`), the fornix-cut
  labels (`Fxcut`) and the empty optic-radiation labels (`OR`) are
  dropped. `CC` is dropped for the same reason: it is an aggregate
  rather than a tract, holding its own forceps (`Fmaj` 96%, `Fmin` 88%
  inside it) so it drew the same fibres twice, and being a sheet rather
  than a bundle its principal curve wandered diagonally across both
  hemispheres instead of following a pathway. That leaves 34 named
  tracts.

- Each view draws only the tracts substantially represented in it,
  rather than every tract that happens to intersect the slab, which left
  each panel cluttered and each tract repeated. Tracts are compared per
  family so left and right stay together, and every tract is drawn in at
  least one view.

- Requires ggseg.extra with the tract-projection orientation, centering,
  cortex-slice and atlas-name fixes; earlier versions mis-place tract
  projections relative to the anatomical reference.

## ggsegAtlastrack 1.0.1

- Atlas 2D geometry migrated to the sf-optional `brain_polygons` format
  (`ggseg.formats` 0.0.3). The atlases now render without `sf` and its
  GDAL/GEOS/PROJ system libraries, enabling wasm and air-gapped
  installs. Plots are unchanged.

## ggsegAtlastrack 1.0.0

- Initial release with AtlasTrack fiber tract atlas
