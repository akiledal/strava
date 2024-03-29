#' Processes gpx files and stores the result in a data frame
#'
#' Processes gpx files and stores the result in a data frame. The code is adapted from the blog post \href{https://rcrastinate.blogspot.com/2014/09/stay-on-track-plotting-gps-tracks-with-r.html}{Stay on track: Plotting GPS tracks with R} by Sascha W.
#' @param path The file path to the directory containing the gpx files
#' @param old_gpx_format If TRUE, uses the old format for gpx files (for files bulk exported from Strava prior to ~May 2018)
#' @keywords
#' @export
#' @examples
#' process_data()

process_data <- function(path, old_gpx_format = FALSE) {
  # Function for processing a Strava gpx file
  process_gpx <- function(file) {
    # Parse GPX file and generate R structure representing XML tree
    pfile <- XML::htmlTreeParse(file = file)

    coords <- XML::xpathSApply(pfile, path = "//trkpt", XML::xmlAttrs)
    # extract the activity type from file name
    type <- str_match(file, ".*-(.*).gpx")[[2]]
    # Check for empty file.
    if (length(coords) == 0) return(NULL)
    # dist_to_prev computation requires that there be at least two coordinates.
    if (ncol(coords) < 2) return(NULL)

    lat <- as.numeric(coords["lat", ])
    lon <- as.numeric(coords["lon", ])
    
    if (old_gpx_format == TRUE) {
      ele <- as.numeric(XML::xpathSApply(pfile, path = "//trkpt/ele", XML::xmlValue))
    }
    
    time <- XML::xpathSApply(pfile, path = "//trkpt/time", XML::xmlValue)

    # Put everything in a data frame
    if (old_gpx_format == TRUE) {
      result <- data.frame(lat = lat, lon = lon, ele = ele, time = time, type = type)
    } else {
      result <- data.frame(lat = lat, lon = lon, time = time, type = type)
    }
    result <- result %>%
      dplyr::mutate(dist_to_prev = c(0, sp::spDists(x = as.matrix(.[, c("lon", "lat")]), longlat = TRUE, segments = TRUE)),
                    cumdist = cumsum(dist_to_prev),
                    time = as.POSIXct(.$time, tz = "GMT", format = "%Y-%m-%dT%H:%M:%OS")) %>%
      dplyr::mutate(time_diff_to_prev = as.numeric(difftime(time, dplyr::lag(time, default = .$time[1]))),
                    cumtime = cumsum(time_diff_to_prev))
    result
  }

  # Process all the files
  data <- mixedsort(list.files(path = path, pattern = "*.tcx", full.names = TRUE)) %>%
    purrr::map_df(process_gpx, .id = "id") %>%
    dplyr::mutate(id = as.integer(id))
}
