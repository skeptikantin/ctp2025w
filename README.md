# ctp2025w

## Analysis of CTP 2025W

### Source
Based on flights that filed a flightplan from/to one of the CTP airports
   and actually departed between 0800z and 1900z on the 26th of April
Source: statsim.net - based on their flight ID
(Script pauses to limit stress on statsim.net - I donated coffee money :))

### Limitations
- the data does not distinguish between normal disconnects and sim crashes
- with the scraping method, and without access to the actual CID-based
  booking data, we cannot ascertained if a pilot reconnected and actually
  finished their flight
- addons/sims cannot be distinguished
- flights cannot be distinguished between traffic with CTP slots or not.
- no filtering on airport slot times; some may have departed outside event
- no filtering whether event pairs were flown

That said, the above limitations, especially concerning resuming one's flight
mid-air are assumed to hold constant across pilots/addons.

### DISCLAIMER
Script/project is not as clean as I would like it to be :)