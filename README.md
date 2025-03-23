# VESC-BBSHD PAS Throttle Cruise


Simple PAS system for a VESC controller and a BBSHD motor. Developed using a Flipsky 75100 and VESC 6.05 firmware and tool.

This was made to remove the need for a throttle (illegal in the UK, or at least "muddy" legality status)

Pas sensors are connected to RX and TX.

My brakes (NYK ZOOM HB-876-E MTB) are simple switches (2 pin connectors) rather than pots (3 pin connectors) - so a 10k resistor from 3.3v connected to ADC2 and then the brake switch from ADC2 to gnd - to make it work properly, no floating values or madness when the motor switches on e.t.c. NOTE - should be the reverse of this so when brakes get disconnected - vesc thinks the kill switch is on and can also test if brakes are connected or not e.t.c.

You'll need to upload these two files to your VESC controller:

- PasThrottleCruise.lisp - calculate the pedal RPM and pedal Count.

- PasThrottleCruise.qml -  The main app which reads the pedal count and exectues a really simple PAS system.
  
- Then on your android phone when the Vesc app connects - a "App UI" tab will appear with the UI for this system

- Nothing will happen or work if your android Vesc app isn't running and connected to your Vesc controller.

It's a "Virtual Throttle", you pedal forwards to increase the cruise speed or pedal backwards to decrease the speed.

Braking will stop everything and reset the target speed to 0.

## Status: In progress 

Probably extremely dangerous at the moment - not to be used at all.

Currently fine tunning and testing. Trying to work out some smooth values e.t.c.

Testing to see if MPH and Battery estimator are correct.

# Absolutely do not use this out on the road. Bench testing only!

Playing around with glES shaders - fun fun fun!

Sadly had to remove most comments in code, get the file sizes down so I could upload to vesc flash e.t.c.

Vesc compresses any QML code to fit onto the tiny amout of free flash space - Which I think it's around 5kb, Vesc Desktop tool has a "calculate size" on the QML page to show you the compressed size.

You'll also need to setup your BBSHD properly for this to work.

## Some important settings include:

PID Controllers->Minimum ERPM  (Mine is set to 600)

PID Controllers->Ramp eRPMs per second (Mine is set to 2500) - this can be used as a acceleration setting, and it seems to be linear in nature. 

Additional Info->Setup->Wheel diameter

App settings->general->Kill Switch mode. (Mine is set to "ADC2 low")

## Brief UI description

The top two big MPH labels are target speed and actual speed.

Accel is a mulitiplier/divider for how many pedal rotations to get to max speed. This is linked to max speed, 20mph max speed takes 2x pedal rotations compared to 10mph e.t.c. Currently it's set to 5 full pedal rotations to get to 10mph.

Panic button STOPS EVERYTHING!

The sigmoid curve - shows the parametric position to the max mph set. i.e. the position of the "Virtual Throttle". 

Horn button does nothing - no QML media libs connected.

Gradient Display removed - no QML sensor libs connected.

MPH buttons set the maxium target speed.

Lock button - locks the app - using the passwords defined.

Using passwordextra instead of password to unlock will display four more speed buttons.

As soon as the motor starts spinning all buttons and sliders are disabled - apart from the "PANIC" button - safety first!

![](./Images/Animation.gif)

# VESC

So far my experience with VESC has been great - hats off to the developers for a really great slick system that enables you to tweak your ESC into whatever you want.

# QML

QML is really nice and simple to make UI's - java style coding - quick and simple.

Sometimes QML code doesn't read the mMcConf proper and returns the wrong wheel size (which can be really dangerous on a system using the wheel size as the main variable for speed calculations).

```
Component.onCompleted:
{
wheelDiameter=mMcConf.getParamDouble("si_wheel_diameter")*39.3701;
wheelDiameter=clamp(wheelDiameter,20,30);
minBat=mMcConf.getParamDouble("l_min_vin")
maxBat=84
}
```
Shaders!!

QML can run glsl shader code - on both the desktop and android versions. Android version seems to use gles 1.00 - and my phones GL compiler is really strict - every numeric literal needs 0.0 formatting. No fwidth,fdfx,fdfy. uniform int or uniform bool don't seem to work on android and so you have to "convert" everything to a float to pass to a uniform:
```
Button
{
Layout.fillWidth: true
text: "UI Col"
id :uicolbutton
font.pointSize : 20
onClicked:
  {
  colourIdx=(colourIdx+2)%colours.length;
  }
background:Rectangle
  {
  layer.enabled: true;
  ShaderEffect
  {
  blending:false;
  width: parent.width
  height: parent.height
  property var source: parent
  property var time: stime
  property var rx : parent.width
  property var ry : parent.height
  property var down : uicolbutton.pressed+0.001 // add 0.0001 to convert pressed to a float!
  property var sc: colours[colourIdx]
  property var ec: colours[colourIdx+1]
  fragmentShader: roundrectvgrad
  }
  }
}
``
Sometimes running QML script on Desktop vesc tool - it will run really slowly and lag a huge amount when sending commands to the VESC controller via bluetooth (a few seconds), that issue doesn't happen on a android phone - not figured out what is going on there - maybe spamming error messages is clogging up the BT comms or something?

# Flipsky

My Flipsky 75100 experience has been ok so far - I don't pull 4kw from it, max 2.5kw for steep hills - just 10-15mph lightweight ebiking on narrow paths - hence the lower speeds and safety.

USB comms: the USB cable - is right next to the phase wires in the cable exit hole on the 75100, so as soon as the motor turns on - USB comms usually fails.

Bluetooth comms: BT is a little flakey - think it's a issue with Winows 11. I developed this using win11 and a android phone, switching between the two was sometimes problematic. You have to wait till the Caps have fully discharged (Blue LED turns off) on the Flipsky when you turn it off before you turn it back on. Win 11 also sometimes doesn't disconnect from the flipsky when you shut down the VESC tool - and so you have to remove the BT device in windows and reboot and start again. When it's in this "stuck" state - nothing can connect to VESC Bluetooth - including android.

# BBSHD

What a superb motor! - built like a tank!! I've ridden 10,000 miles plus over the 5 years I've owned the BBSHD. No problems with it at all - no noises or issues. I gear 28/32 for hill climbing torque and I think that's the key to the BBSHD longevity - it likes to spin fast (all motors do :) ) - and that stops the internal nylon gear from melting!

Gearing low - not only saves the nylon gear - it also saves the chain - I've had the same flimsy chain for 10,000 miles - zero damage to it - even on extreme hills (up to 35% grads).

In fact a single gear setup, is perfect with BBSHD - no messing with derailleurs and all the problems they bring (they're just not up to spec to handle 2500w+). You can then choose your gearing to fit your ridiing environment and that's a massive improvement over fixed gear hub motors.

High Voltage!!! That's also another key to BBSHD longevity - the higher the voltage the faster the motor can spin, also Higher voltage means less current and less "copper loses" for the same amount of power. Less current also has less wear on your batteries. So it's a win win situation all round!

so Gear low and Voltage high!!!

BBSHD has a 24kv rating? so 72v=1636 rpm = 1636x8x21.9 = 291456 erpm. (not sure how accurate or correct these figures are)

BBSHD pas sensor seems to have 24 magnets - so with 4x encoder reading that gives 96 discrete pedal positions.

# Safety Lecture

The BBSHD is a very powerful motor - if things go wrong it can easily overpower you (2.5kw = 3.3HP!) and pull you into traffic and splat. This system uses PID setRpm() - so it will attempt to match the speed you set - and ramp up the power until it reaches that speed. So unless you know what you are doing with this kind of software - just don't bother - you have to consider this "Life Critical" code - and apply development thoughts with that as the Key feature.

- if your brake cable disconnects - you can shut off the motor with the panic button or shutdown the app or disconnect the battery.
 
Programming is always prone to errors - it's the only sensible way to approach "life crictical" software - so you need bench test this first - wheels off ground or chain removed and make sure the speeds are correct e.t.c. 
