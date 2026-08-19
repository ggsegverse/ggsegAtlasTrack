# AtlasTrack Fiber Tract Atlas

Brain atlas for the AtlasTrack probabilistic white matter fiber tract
parcellation, commonly used with ABCD study data.

## Usage

``` r
atlastrack()
```

## Value

A
[ggseg.formats::ggseg_atlas](https://ggsegverse.github.io/ggseg.formats/reference/ggseg_atlas.html)
object.

## References

Hagler DJ Jr, et al. (2019). "Image processing and analysis methods for
the Adolescent Brain Cognitive Development Study." *NeuroImage*,
202:116091.
[doi:10.1016/j.neuroimage.2019.116091](https://doi.org/10.1016/j.neuroimage.2019.116091)

## Examples

``` r
atlastrack()
#> 
#> ── atlastrack ggseg atlas ──────────────────────────────────────────────────────
#> Type: tract
#> Regions: 34
#> Hemispheres: right, left, midline
#> Views: coronal, inferior_axial, mid_axial, sagittal, superior_axial
#> Palette: ✔
#> Rendering: ✔ ggseg
#> ✔ ggseg3d (centerlines)
#> ────────────────────────────────────────────────────────────────────────────────
#>     hemi region label
#> 1  right   r fx  R_Fx
#> 2   left   l fx  L_Fx
#> 3  right  r cgc R_CgC
#> 4   left  l cgc L_CgC
#> 5  right  r cgh R_CgH
#> 6   left  l cgh L_CgH
#> 7  right  r cst R_CST
#> 8   left  l cst L_CST
#> 9  right  r atr R_ATR
#> 10  left  l atr L_ATR
#> ... with 24 more rows

library(ggseg.formats)
plot(atlastrack())
```
