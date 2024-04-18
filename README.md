[![GitHub license](https://img.shields.io/github/license/bob01/etxwidgets)](https://github.com/bob01/etxwidgets/main/LICENSE)


# Welcome to etxWidgets for EdgeTX and RotorFlight
**Screen elements for R/C Helicopters**


### About etxWidgets
These widgets have been designed by R/C Heli pilots for R/C Heli pilots.
The goal is to present the relevant telemetry expected from modern R/C systems before, during and after flight with on-screen, audio and haptic elements.


# etxPowerbar
![image](https://github.com/bob01/etxwidgets/assets/4014433/1c7d1313-ad04-4649-84a1-b2fb1ca4af48)
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

### Settings
- VoltSensor    battery voltage telemetry sensor, e.g. RxBt or Batt
- PcntSensor    battery % consumpumed telemetry sensor, e.g. Bat%
- MahSensor     battery current consumed (mah) telemetry sensor, e.g. Capa, Used
- Reserve       percentage reseerve, usually 20 - 30%. Pilot can then simply fly to 0% on the powerbar 
- Cells         cell count. 0 for auto detect - displayed count flashes '?' during cell detection, it is important to wait for the result before moving on as a depleted pack may be identified as a full pack with 1 cell less. e.g. dead 12S identified as full 10 or 11S. Reccommend just setting this explicitly to remove all uncertainty.

etxPowerbar was based on the the excellent 'BattAnalog' widget by Offer Shmuely
