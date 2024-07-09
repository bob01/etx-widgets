[![GitHub license](https://img.shields.io/github/license/bob01/etxwidgets)](https://github.com/bob01/etxwidgets/main/LICENSE)


# Welcome to etxWidgets for EdgeTX and RotorFlight
**Screen elements for R/C Helicopters**


### About etxWidgets
These widgets have been designed by R/C Heli pilots for R/C Heli pilots.
The goal is to present the relevant telemetry expected from modern R/C systems before, during and after flight with on-screen, audio and haptic elements.

### Release notes
2024.07.09 - eThrottle - Report "Bad Auto" + haptic if GOV reports LOST-HS ie bailout will not be available
2024.06.30 - eThrottle - GOV status aware of using [crsf_flight_mode_reuse = GOVERNOR] - very useful w/ setting up auto bailout etc.


# ePowerbar
![image](https://github.com/bob01/etxwidgets/assets/4014433/31942e6a-a4ba-4ae8-943b-a3cb83a7d4ab)
![image](https://github.com/bob01/etxwidgets/assets/4014433/aed6ee88-e325-405c-bf60-df8a25913d84)
![image](https://github.com/bob01/etxwidgets/assets/4014433/085ecfe2-60d3-499f-bcd6-84455cb73eca)
![image](https://github.com/bob01/etxwidgets/assets/4014433/d0a0d1fe-a1ee-46ae-a0b3-61e6d423d117)

### Features
- does voice callouts every 10% w/ 1% callouts for the last 10
- optional cell count auto-detection.
- flashes and callout a voltage warning if battery connected isn't fully charged (after cell count detection).
Flashing will continue to indicate that flight started with a partially charged battery making consumption monitoring possibly inaccurate
- changes color to yellow at 30% and red for the last 20% or...
- allows specification of a "reserve" %. In that case pilot flys to 0, bar goes red if pilot chooses to go further
- critial alerts will be accompanied by a haptic vibe

### Settings
- VoltSensor:    battery voltage telemetry sensor, e.g. RxBt or Batt
- PcntSensor:    battery % consumpumed telemetry sensor, e.g. Bat%
- MahSensor:     battery current consumed (mah) telemetry sensor, e.g. Capa, Used
- Reserve:       percentage reseerve, usually 20 - 30%. Pilot can then simply fly to 0% on the powerbar 
- Cells:         cell count. 0 for auto detect - displayed count flashes '?' during cell detection, it is important to wait for the result before moving on as a depleted pack may be identified as a full pack with 1 cell less. e.g. dead 12S identified as full 10 or 11S. Reccommend just setting this explicitly to remove all uncertainty.

ePowerbar was based on the the excellent 'BattAnalog' widget by Offer Shmuely


# eThrottle
![image](https://github.com/bob01/etxwidgets/assets/4014433/fb6135be-484a-4159-aaa3-a8dc52de5a39)
![image](https://github.com/bob01/etxwidgets/assets/4014433/d935f4f2-1cbb-4d3b-8c24-8a240bb498ed)
![image](https://github.com/bob01/etxwidgets/assets/4014433/a94fffd5-9e0a-4e15-a427-3ec466ef6cd0)
![image](https://github.com/bob01/etxwidgets/assets/4014433/4ebc46c3-676f-43f6-befc-153ae7bc294d)

### Features
- uses RotorFlight's (FC) flight mode telemetry sensor to indicate the actual true "safe" / "armed" state of the flight controller w/ voice callout
- displays the FC's flight mode telemetry sensor to help tell what's happening if you're standing there and FC won't arm
- displays ESC last most significant status + log of last 128 messages in full screen mode, purpose is to help understand unexpected powerloss etc at the flightline or pits w/o a laptop
For all ESC's with status flags (requires FC inclusion of ESC telemetry status, avaiable in RotorFlight soon)
Currently only YGE decoded/supported, more coming soon.

### Settings
- ThrottleSensor:      throttle % telemetry sensor, e.g. Thro
- FlightModeSensor:    flight mode telemetry sensor, e.g. FM
- EscStatus:           esc status telemetry sensor - leave unset "---" if not supported by ESC or flight controller version
- Status:              enable / disable flight controller status in the widget's upper right above the throttle % / Safe 
- Voice:               enable / disable voice


# Installation
- download and unzip etx-widgets-main.zip
- connect the radio and copy these folders from the zip file to the radio
![image](https://github.com/bob01/etx-widgets/assets/4014433/876cdaa9-a6a7-46b9-8e36-bde02218bb6b)
![image](https://github.com/bob01/etx-widgets/assets/4014433/56171f48-e973-4ed5-9220-a4d11e5756e8)
