# PAS Throttle Cruise #


Simple PAS system for VESC BBSHD.


Pas sensors are connected to RX and TX.

My brakes are simple switches rather than pots - so a 10k resistor from 3.3v connect to adc2 to make it work properly.


PasThrottleCruise.lisp - calculated the pedal RPM and pedal Count.

PasThrottleCruise.qml - reads the pedal count and exectues a really simple PAS system.

It's a "Virtual Throttle", you pedal forwards to increase the cruise speed or pedal backwards to decrease the speed.

Status: In progress - fine tunning and testing. Absolutely do not use this out on the road.

The top two big MPH labels are target speed and actual speed.

![](./Images/MainApp.png)
