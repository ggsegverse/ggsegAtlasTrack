#' AtlasTrack Fiber Tract Atlas
#'
#' Brain atlas for the AtlasTrack probabilistic white matter fiber tract
#' parcellation, commonly used with ABCD study data.
#'
#' @family ggseg_atlases
#' @family tract_atlases
#'
#' @references Hagler DJ Jr, et al. (2019). "Image processing and analysis
#'   methods for the Adolescent Brain Cognitive Development Study."
#'   *NeuroImage*, 202:116091.
#'   \doi{10.1016/j.neuroimage.2019.116091}
#'
#' @return A [ggseg.formats::ggseg_atlas] object.
#' @import ggseg.formats
#' @export
#' @examples
#' atlastrack()
#' \dontrun{plot(atlastrack())}
atlastrack <- function() .atlastrack
