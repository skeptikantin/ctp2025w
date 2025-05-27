# CTP 2025E Analysis ------------------------------------------------------

# Prelims -----------------------------------------------------------------
rm(list=ls(all=TRUE))

library(tidyverse)
library(sf)

# load data
ctp_data <- read.delim("~/coding/ctp2025w/data/ctp_data.csv")

# Wrangle -----------------------------------------------------------------

# identify: made it
ctp <- ctp_data |> 
  mutate(arrived = if_else(arr_time == "N/A", "no", "yes"),
         arr_time = if_else(arr_time == "N/A", NA, arr_time)) |> 
  # time data
  mutate(last_known = str_remove(last_known, "z")) |> 
  mutate_at(c("dep_time", "arr_time", "last_known"), as_datetime, format = '%Y-%m-%d %H:%M') |> 
  # time airborne
  mutate(airborne = case_when(
    is.na(arr_time) ~ last_known - dep_time,
    !is.na(arr_time) ~ arr_time - dep_time,
    .default = NA
  )) |> 
  mutate(airborne = hms::as_hms(airborne)) |> 
  # is A350
  mutate(a350 = if_else(aircraft %in% c("A359", "A35K"), aircraft, "other")) |> 
  # lump factors below 10 total:
  mutate(aircraft_type = fct_lump_n(factor(aircraft), n = 10, other_level = "other"), .after = aircraft) |> 
  # factor
  mutate(arrived = factor(arrived))

# Visualizations ----------------------------------------------------------

## percentage survived ----
ctp_perc <- ctp |> 
  select(aircraft_type, arrived) |> 
  group_by(aircraft_type, arrived) |> 
  count(name = "total") |> #View()
  arrange(desc(total)) |> 
  pivot_wider(names_from = "arrived", values_from = "total", values_fill = 0) |> 
  mutate(total = yes + no,
         perc_survived = yes / (yes + no)) |> #View()
  arrange(desc(perc_survived))

# add CTP average across all "participating" aircraft
ctp_perc_all <- ctp |> 
  select(arrived) |> 
  group_by(arrived) |> 
  count(name = "total") |> 
  pivot_wider(names_from = "arrived", values_from = "total", values_fill = 0) |> 
  mutate(total = yes + no,
         perc_survived = yes / (yes + no)) |> 
  mutate(aircraft_type = "CTP average", .before = 1) |> #View()
  arrange(desc(perc_survived))

# add to ctp_perc
ctp_perc <- ctp_perc |> 
  bind_rows(ctp_perc_all) |> 
  arrange(desc(perc_survived))

# barplot of aircraft survival rates
ctp_perc |> 
  ggplot(aes(x = reorder(aircraft_type, perc_survived), y = perc_survived, fill = total)) + 
  geom_bar(stat = "identity", width = .5) +
  labs(title = "Percentage of flights that reached their destination during CTP2025W",
       x = "Aircraft type", y = "Percentage survived",
       caption = "statsim.net - all flights that filed flightplans to/from CTP event airports and departed between 0800z and 1900z on April 26th, 2025\nLimitations include: flights that never left the ground/gate are not included, and data does not distinguish sim crashes and other types of disconnects",
       fill = "Number of aircraft") +
  coord_flip() +
  hrbrthemes::theme_ipsum_gs() +
  viridis::scale_fill_viridis(direction = -1) +
  guides(colour = guide_colourbar(title.position="top", title.hjust = 0.5),
         fill = guide_colourbar(title.position="top", title.hjust = 0.5)) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_fill_viridis_c(limits = c(0, 350), direction = -1) +
  theme(legend.position = "top",
        legend.key.size = unit(1, "cm"),
        legend.key.height = unit(0.2, "cm"))

ggsave(filename = "plots/percentage_lost.pdf", device = cairo_pdf, height = 6, width = 10, dpi = 300)

# average airborne time
ctp |> 
  filter(arrived == "no") |> 
  group_by(aircraft_type) |> 
  summarize(avg_airborne = round(seconds_to_period(mean(airborne)))) |> 
  arrange(desc(avg_airborne))

## phase of flight ----

ctp |> 
  filter(arrived == "no") |> 
  filter(airborne > 0) |> 
  ggplot(aes(airborne, altitude, fill = a350)) +
  geom_point(aes(color = a350), size = 1.5) +
  labs(title = "Phase of flight when aircraft disconnected",
       y = "Last known altitude", x = "Survival duration") +
  scale_color_manual(values=c("#fde725", "#46327e", "grey80")) +
  hrbrthemes::theme_ipsum_gs() +
  theme(legend.position = "top", legend.title=element_blank())

ggsave(filename = "plots/survival_time_altitude.pdf", device = cairo_pdf, height = 6, width = 10, dpi = 300)

## survival duration ----
ctp_box <- ctp |> filter(arrived == "no")
ctp_box$aircraft_type = with(ctp_box, reorder(aircraft_type, airborne, median))

ctp_box |> 
  group_by(aircraft_type) |> 
  mutate(total_aircraft = n()) |> 
  ggplot(aes(aircraft_type, airborne, fill = aircraft_type)) +
  geom_boxplot(varwidth = TRUE) +
  geom_point(size = 1, alpha = .5,
    position = position_jitter(
      seed = 1, width = .2
    )
  ) +
  labs(x = "",
       y = "Time airborne in hours",
       title = "Survival duration of aircraft that did not reach their destination during CTP 2025W",
       subtitle = "Width of bars indicates total number of aircraft in CTP") +
  hrbrthemes::theme_ipsum_gs() +
  theme(legend.position = "none")

ggsave(filename = "plots/survival_time.pdf", device = cairo_pdf, height = 6, width = 10, dpi = 300)


## last seen (map) ----

ctp_sf <- st_as_sf(ctp, coords = c('longitude', 'latitude'))

# plot
ggplot(ctp_sf |> filter(arrived == "no")) + 
  borders("world", colour = "grey85", size = .2) +
  geom_sf(aes(color = a350)) +
  #theme_void(base_family = "Goldman Sans Condensed") +
  hrbrthemes::theme_ipsum_gs() +
  scale_color_manual(values=c("#fde725", "#46327e", "grey80")) +
  coord_sf(xlim = c(-120, 40), ylim = c(10, 80)) +
  theme(legend.position = "top", legend.title=element_blank(),
        axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        panel.grid.major = element_blank()) +
  labs(title = "CTP2025W Hunger Games",
       subtitle = "Of those who didn't reach their destination, where were they last seen?",
       y = "", x = "")

ggsave(filename = "plots/last_seen.pdf", device = cairo_pdf, height = 6, width = 10, dpi = 300)


# Analysis ----------------------------------------------------------------


# Modelling ---------------------------------------------------------------
library(party)

# most variables make no sense, method is quick-and-dirty, but it identifies
# two groups with significant difference between the groups, but no difference
# between members of each group. Variables not in final tree do not contribute
# to explaining the variance.

# Create the tree.
output.tree <- ctree(
  arrived ~ factor(aircraft_type) + factor(ades) + factor(adep) + as.numeric(flight_id), 
  data = ctp)

# Plot the tree.
plot(output.tree, title = "Survived")

### TBC.