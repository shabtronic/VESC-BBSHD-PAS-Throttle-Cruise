# PAS Throttle Cruise


Simple PAS system for a VESC controller and a BBSHD motor. Developed using a Flipsky 75100 and VESC 6.05 firmware and tool.

This was made to remove the need for a throttle (illegal in the UK, or at least "muddy" legality status)

Pas sensors are connected to RX and TX.

My brakes are simple switches rather than pots - so a 10k resistor from 3.3v connected to adc2 and then the brake switch from ADC2 to gnd - to make it work properly.

You'll need to upload these two files to your VESC controller:

- PasThrottleCruise.lisp - calculate the pedal RPM and pedal Count.

- PasThrottleCruise.qml -  The main app which reads the pedal count and exectues a really simple PAS system.

It's a "Virtual Throttle", you pedal forwards to increase the cruise speed or pedal backwards to decrease the speed.

Braking will stop everything and reset the target speed to 0.

## Status: In progress 

Currently fine tunning and testing. Trying to work out some smooth values e.t.c.

Testing to see if MPH and Battery estimator are correct.

# Absolutely do not use this out on the road. Bench testing only!

Playing around with glES shaders - fun fun fun!

Sadly had to remove most comments in code, get the file sizes down so I could upload to vesc flash e.t.c.

You'll also need to setup your BBSHD properly for this to work.

## Some important settings include:

PID Controllers->Minimum ERPM  (Mine is set to 600)

PID Controllers->Ramp eRPMs per second (Mine is set to 2500)

Additional Info->Setup->Wheel diameter

App settings->general->Kill Switch mode. (Mine is set to "ADC2 low")

## Brief UI description

The top two big MPH labels are target speed and actual speed.

Accel is how fast the erpm will get up to the target speed. (done with a 6db lpf)

Panic button STOPS EVERYTHING!

The sigmoid curve - shows the parametric position to the max mph set. i.e. the position of the "Virutal Throttle". 

Horn button does nothing - no QML media libs connected.

Gradient Display removed - no QML sensor libs connected.

MPH buttons set the maxium target speed.

Lock button - locks the app - using the passwords defined.

passwordextra unlocks more speed buttons.

![](./Images/PasThrottleCruiseAnim.gif)
