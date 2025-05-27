# Analysis of CTP 2025W ---------------------------------------------------

# Based on flights that filed a flightplan from/to one of the CTP airports
#   and actually departed between 0800z and 1900z on the 26th of April
# Source: statsim.net - based on their flight ID
#   (Script pauses to limit stress on statsim.net - I donated coffee money :))

# Limitations:
#  - the data does not distinguish between normal disconnects and sim crashes
#  - with the scraping method, and without access to the actual CID-based
#    booking data, we cannot ascertained if a pilot reconnected and actually
#    finished their flight
#  - addons/sims cannot be distinguished
#  - flights cannot be distinguished between traffic with CTP slots or not.
#  - no filtering on airport slot times; some may have departed outside event
#  - no filtering whether event pairs were flown

# That said, the above limitations, especially concerning resuming one's flight
# mid-air are assumed to hold constant across pilots/addons.

# DISCLAIMER: script is not as clean as I would like it to be :)

# Prelims -----------------------------------------------------------------

rm(list=ls(all=TRUE))
library(tidyverse)
library(rvest)

# Fetch flight ids --------------------------------------------------------

# define departure and arrival airports
adeps <- c("EBBR", "EDDB", "EFHK", "EGCC", "EHAM", "EIDW", "ESSA", "EVRA",
           "GMMN", "LEBL", "LFPG", "LIRF", "LOWW", "LPPT", "UUEE")
adess <- c("CYYZ", "KORD", "CYWG", "CYVR", "CYUL", "CYYC", "KMIA", "TJSJ",
           "KPHL", "KMCO", "KPHX", "KSEA", "KIAD", "SBGR", "SBGL", "SKBO",
           "KDEN", "KDTW", "KBOS", "TFFR", "TTPP", "KIAH", "TBPB")

# container to fetch data
ctp_deps <- data.frame()

for (i in 1:length(adeps)) {

  # make url to fetch daily departures from
  apt_url <- paste0("https://statsim.net/flights/airport/?icao=", adeps[i], "&period=custom&from=2025-04-26+06%3A00&to=2025-04-26+19%3A00")

  # fetch html contents
  apt_html <- read_html(apt_url)
  
  # extract table rows
  rows <- apt_html |> 
    html_nodes("tr")
  
  # find the header node (e.g., "Departed")
  header_node <- apt_html |> 
    html_nodes("h3") |> 
    purrr::keep(~ grepl("Departed", html_text(.))) |> 
    .[[1]]  # take the first match
  
  # get the next sibling node (assumed to be the table under the header)
  table_node <- html_node(header_node, xpath = "following-sibling::table[1]")
  
  # extract the rows from that table
  rows <- html_nodes(table_node, "tr")
  
  # extract data from each row
  ctp_apts <- rows |> 
    purrr::map_df(function(row) {
      flight_node <- html_node(row, "td:nth-child(1) a")
      
      dplyr::tibble(
        callsign = html_text(flight_node),
        flight_id = html_attr(flight_node, "href"),
        datetime = html_text(html_node(row, "td:nth-child(2)")),
        ades = html_text(html_node(row, "td:nth-child(3)")),
        aircraft = html_text(html_node(row, "td:nth-child(4)"))
      )
    })
  
  # clean data
  ctp_apts <- ctp_apts |> 
    # select flights between CTP apts
    filter(ades %in% adess) |> 
    filter(!is.na(ades)) |> 
    mutate(flight_id = str_remove(flight_id, "^.+?/\\?flightid=")) |> 
    mutate(adep = adeps[i], .before = ades)
  
  # add to main frame
  ctp_deps <- rbind(ctp_deps, ctp_apts)
  
  # pause script for 10 seconds
  Sys.sleep(sample(15:30, 1))
  
  print(paste("Processed", i, "of", length(adeps)))
  
}

## interim save
save(ctp_deps, file = "data/ctp_deps.RData")

# Fetch flight data per flight id -----------------------------------------

# two sets of data need to be fetched:
#  1) whether flight made it to destination
#  2) the geo positions per flight

# define the URL of the flight details page
fltd_id <- ctp_deps$flight_id

# define container to store data
fltd_data <- data.frame()

for (i in 1:length(fltd_id)) {

  # define url
  fltd_url <- paste0("https://statsim.net//flights/flight/?flightid=", fltd_id[i])
  
  # read the HTML content of the page
  page <- read_html(fltd_url)
  
  # extract waypoint data and keep the last known position
  waypoints <- page |> 
    html_node("body > div.container > div > main > div:nth-child(5) > div > table") |> 
    html_table(fill = TRUE) |> 
    as_tibble() |> 
    # last known position
    slice(n()) |> 
    rename(last_known = Time)
  
  # extract the parent container
  col5 <- page |> 
    html_node("body > div.container > div > main > div:nth-child(4) > div.col-5")
  
  # extract the two specific tables
  adep <- col5 |> 
    html_node("table:nth-child(2)") |> 
    html_table(fill = TRUE) |> 
    as_tibble() |> 
    rename(dep_time = X2) |> 
    slice_head(n = 1) |> 
    select(dep_time)
  
  ades <- col5 |> 
    html_node("table:nth-child(4)") |> 
    html_table(fill = TRUE) |> 
    as_tibble() |> 
    rename(arr_time = X2) |> 
    slice_head(n = 1) |> 
    select(arr_time)
  
  # combine all
  fltd_id_dat <- fltd_id[i] |> 
    tibble() |> 
    bind_cols(adep, ades, waypoints) |> 
    janitor::clean_names()
  
  # add to total df
  fltd_data <- rbind(fltd_data, fltd_id_dat)
  
  # pause script for 10 seconds
  Sys.sleep(sample(5:10, 1))
  
  print(paste(round(Sys.time()), "Processed", i, "of", length(fltd_id)))

}

## save
save(fltd_data, file = "data/fltd_data.RData")

# fix some weird shit
fltd_data <- fltd_data |> 
  rename(flight_id = fltd_id_i)

# combine
ctp_data <- ctp_deps |> 
  left_join(fltd_data)

# save full data set
save(ctp_data, file = "data/ctp_data.RData")
write.table(ctp_data, file = "data/ctp_data.csv", quote = FALSE, sep = "\t", row.names = FALSE)
