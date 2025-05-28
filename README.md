# ctp2025w

## Analysis of CTP 2025W

### Data source
Based on flights that filed a flightplan from/to one of the CTP airports and actually departed between 0800z and 1900z on the 26th of April

Source: statsim.net

(Script pauses to limit stress on statsim.net - I donated coffee money :))

### Files

- ctp2025w_scrape.R - "quick" and dirty script to scrape data from statsim.net
- ctp2025w_analysis.R - EDA, data viz, preliminary classification modelling
- **data/ctp_data.csv is the main file with all the data.** The .RData containers are interim/backup saves during the scraping process and can be ignored

### Questions & short story

During CTP2025W, there were a lot of complaints about the stability of the Inibuilds A350 addons. If those aircraft types (A359, A35K) were indeed subject to some substantial issues, we should expect substantially lower survival rates and certain clusters of disconnects ("patterns/trends").

The short story seems to be: while the data is inherently noisy, there is not enough evidence to support the claim that Inibuilds A350s crashed significantly more often. It is probably true that they are among the less stabile addons **in the current data**, this pattern is not unique to A350s; at most, it's Airbus addons _in general_.

### Limitations
- the data does not distinguish between normal disconnects and sim crashes
- with the scraping method, and without access to the actual CID-based
  booking data, we cannot ascertained if a pilot reconnected and actually
  finished their flight
- addons/sims cannot be distinguished
- flights cannot be determined whether they were traffic with CTP slots or not
- no filtering on airport slot times; some may have departed outside event
- no filtering whether event pairs were flown or not
- for many aircraft types, it is impossible to draw any conclusion as the distribution across different devs is unknown

That said, the above limitations, especially concerning disconnects and/or whether pilots had a booked slot or not are assumed to hold constant across pilots/addons or negligible.

### DISCLAIMER
Script/project is not as clean as I would like it to be :)