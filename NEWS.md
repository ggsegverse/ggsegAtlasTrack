# ggsegAtlasTrack 2.0.0

- `atlastrack` is now a proper **white-matter tract atlas** (`type = "tract"`)
  instead of a subcortical volume atlas. Each fiber tract is reduced to a
  principal-curve centerline and rendered as a 3D tube and a 2D projection on a
  grey-brain context, matching the FreeSurfer tract look, rather than as
  overlapping slice blobs. Built with the new
  `ggseg.extra::create_tract_from_volume()` from the source label volume. The
  aggregate whole-brain fibre masks (`AllFib*`) and empty optic-radiation labels
  are dropped, leaving 35 named tracts.

# ggsegAtlastrack 1.0.1

- Atlas 2D geometry migrated to the sf-optional `brain_polygons` format
  (`ggseg.formats` 0.0.3). The atlases now render without `sf` and its
  GDAL/GEOS/PROJ system libraries, enabling wasm and air-gapped installs.
  Plots are unchanged.

# ggsegAtlastrack 1.0.0

- Initial release with AtlasTrack fiber tract atlas
