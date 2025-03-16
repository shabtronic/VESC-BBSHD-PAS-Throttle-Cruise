import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2
//import QtSensors 5.0
//import Sensors 1.0
//import QtMultimedia 4.0
import Vedder.vesc.utility 1.0
import Vedder.vesc.commands 1.0
import Vedder.vesc.configparams 1.0

// PAS Throttle Cruise UI
//
// (C) 2025 S.D.Smith all rights reserved
//
// *CAUTION* I class this as "LIFE CRITICAL" code so use at your *OWN* risk -
// I accept no liablility for any damage or injury incured using this software.
// Only use this is if you *KNOW* what your are doing, and have done plenty of "bench" testing
// ("bench" testing - meaning wheels off ground or chain removed so your bike can't move)

// This has only been tested on a BBSHD with a Flipsky 75100
// the BBSHD is a very powerful motor up to 4kw with the right settings - so you need to be
// very very careful with it.
// You need to have setup your BBSHD correctly - and that's a whole other chunk of knowledge
// not discussed here.

// If your motor settings are not correct - this script may fail to stop your motor when setRPM(0) is called!

// You need to "upload" PasThrottleCruise.lisp to your vesc controller for this to work
// that lisp script calculates the pedalRPM and pedalCount and sends it to this QML script

// You need to upload this QML script to your vesc controller
// You need to hit the bin button on the (main) script window - then load this script
// then on the bottom part of the screen "Tools"->Erase and Upload

// You need to set "App Settings"->"General"->"App to use" to CUSTOM_USER_APP

// Because Brakes are so important for this kind of Cruise system
// the App has a brake "test" at the start and will not continue unless the brakes are pressed
// You *MUST* setup the brakes manually - else this system will potentially not switch off!!
// You need to set "App Settings"->"General"->"Kill switch mode" - to whatever your brakes are wired up as
// Test this by hitting the brakes while this qml is running - a Group box will appear with "Braking" in red text!

// Usage:
//
// 1) This is a PAS Throttle Cruise system, you pedal forwards to start the motor
// 2) The motor will only start if the pedal RPM is above the pedal Thresh set with the slider
// 2) The motor will speed up to the TargetSpeed you've set (10,12 or 15mph)
// 4) The motor will accelerate to the TargetSpeed (in MPH increase per second) you've set with the Accel slider and set button
// 5) While the motor is running if you pedal forwards above the pedalThresh the TargetSpeed will increase by a small amount
// 6) While the motor is running if you pedal backward above the pedalThresh the TargetSpeed will decrease
// 7) The motor will stop if you hit the brakes (and have them wired up correctly and set the app settings correctly)
// 8) The motor will stop if you hit the "PANIC" button
// 9) The motor will stop if you shut down the app
// 10) The lock button will only work if the RPM is 0
// 11) If you press any of the 10mph,12mph,15mph buttons while the motor is running
//     the motor will accel/decel to that speed
// 12) The motor will stop if you stop pedalling (pedalRPM<=0.5) - unless the "Cruise" toggle is on


// Press the lock button to shutdown the motor and turn off the UI
// Enter password defined below to display the UI

// BBSHD has 8 magnets
// 21.9 internal gear ratio
// 28t(crank)/32t(rear wheel)) external gear ratio

// Sliders Buttons and Toggles are all separated vertically as much as possible for safety
// You don't want them close together and accidentally press the wrong thing
// which can and does happen with touch screens while riding!

// While the fantastic Gauges and Dials in the vesc app look really great,
// On a android phone there's not much screen estate - so I've opted for a
// Easy to read Text display UI whilst riding.

Item {
    // SDS - sadly no meida libs for the Android vesc app :(
    //SoundEffect
    //{
    //    id: playSound
    //    source: "soundeffect.wav"
    //}

    property Commands mCommands: VescIf.commands()
    property ConfigParams mMcConf: VescIf.mcConfig()

    // 120 pedal rpm = 10 mph
    // 10 mph = 21024

    // trigger onValuesSetupReceived
    Component.onCompleted:
    {
        mCommands.emitEmptySetupValues()
        var testspeed=10
        console.log("GEARS/ERPM Calculations test:")
        console.log(testspeed.toFixed(1)+" mph to erpm: "+convMPHtoERPM(testspeed).toFixed(0))
        console.log(testspeed.toFixed(1)+" mph to erpm to mph: "+convERPMtoMPH(convMPHtoERPM(testspeed)).toFixed(0))
    }

    // SDS - various Globals
    // Gear ratios - crank and wheel are teeth counts
    // motor ratio is the internal gearing on the BBSHD
    // These are all used to convert ERPM to MPH e.t.c.

    property var motormagnets: 8
    property var motorratio: 21.9
    property var crankgear: 28
    property var wheelgear: 32
    property var gearRatio: (motormagnets*motorratio*wheelgear/crankgear) // convert to and from ERPM/MPH

    // We actually read this from the vesc mcConf - so this setting gets overwritten
    // makes it easer to change tyres/wheels without having to change src code e.t.c.
    property var wheelDiameter: 28.5 // inches - fat bike 26" + stupidly big tyres = 28.5"!!

    property var incrementalCruise: true; // enable/disable cruise


    // Change to whatever you like!
    property var password : "353838"
    // unlock "extra speeds"
    property var passwordextra : "353538"

    property var componentsVisible: false // set to false for brake test
    property var passwordVisible: false
    property var extrasVisible: false
    property var errorVisible: true // set to true for brake test
    property var brakesTested: false // set to false for brake test


    // Safety - test the brakes - before allowing app to run

    // Various
    property var totalTime: 0 // main trip time
    property var motorRPM: 0
    property var motorTime: 0.0000001 // motor on time
    // Safety Values
    property var maxMPH: 10
    property var minMPH: 2
    // Battery
    property var minBattery:0
    property var maxBattery:84
    property var batteryPercentage:0
    property var batteryPercentageStart:0
    // Trip values
    property var distTravelled: 0


    // Lisp PAS vars
    property var pasPedalRPM:0
    property var pasPedalCount:0

    // main vars for motor control
    property var targetERPM: 0
    property var actualERPM: 0
    property var pedalStatic:-1000000

    function updateMotor()
    {
        actualERPM+=(targetERPM-actualERPM)*accelSlider.value;
        if (actualERPM>0 && actualERPM<70000)
        mCommands.setRpm(actualERPM)
    }

    // SDS Various conversion functions
    function convERPMtoWheelRPM(erpm)
    {
            return erpm/(motormagnets*motorratio*crankgear/wheelgear)
    }

    property var inchespermile: 63360

    function convERPMtoMPH(erpm)
    {
         return erpm/((inchespermile/(wheelDiameter*Math.PI*60.0))*(motormagnets*motorratio*crankgear/wheelgear))
    }

    function convMPHtoERPM(mph)
    {
        return (mph*inchespermile/(wheelDiameter*Math.PI*60.0))*(motormagnets*motorratio*crankgear/wheelgear)
    }

    // Lazy group buttons
    function buttonActive(idx)
        {
            if (idx==1) b1.Material.background= "#008f00"
            else b1.Material.background= "#404040"
            if (idx==2) b2.Material.background= "#008f00"
            else b2.Material.background= "#404040"
            if (idx==3) b3.Material.background= "#008f00"
            else b3.Material.background= "#404040"
            if (idx==4) b4.Material.background= "#008f00"
            else b4.Material.background= "#404040"
            if (idx==5) b5.Material.background= "#008f00"
            else b5.Material.background= "#404040"
            if (idx==6) b6.Material.background= "#008f00"
            else b6.Material.background= "#404040"
            if (idx==7) b7.Material.background= "#008f00"
            else b7.Material.background= "#404040"
            if (idx==8) b8.Material.background= "#008f00"
            else b8.Material.background= "#404040"
         }

 // comms handlers for data from vesc/lisp
 Connections
 {

 property Commands mCommands: VescIf.commands()
 property ConfigParams mMcConf: VescIf.mcConfig()
 target: mCommands

  // SDS - get data from LispBM
 function onCustomAppDataReceived(data)
 {
   var dv = new DataView(data, 0)
   pasPedalRPM = dv.getUint8(0)-128
   var paspc1=dv.getUint8(1)
   var paspc2=dv.getUint8(2)
   var paspc3=dv.getUint8(3)
   pasPedalCount= (paspc1+(paspc2*256)+(paspc3*256*256))-(256*256*256/2)
   if (!bikeLocked && brakesTested==true)
        {
        // Calculate target speed from pedalcount
        if (pedalStatic==-1000000)
            pedalStatic=pasPedalCount;
        var pedalDelta=0;
        if (pedalStatic!=-1000000)
            {
            pedalDelta= (pasPedalCount-pedalStatic)/500*10;
            if (pedalDelta<0)
                {
                pedalDelta=0;
                pedalStatic=pasPedalCount
                }
            if (pedalDelta>maxMPH)
                {
                pedalDelta=maxMPH;
                pedalStatic=pasPedalCount-(pedalDelta*500/10)
                }
            targetERPM=convMPHtoERPM(pedalDelta*speedmulSlider.value)
            }
            else
            {
            pedalDelta=0;
            }

    //pedalLabel.text= "Delta "+(pedalDelta).toFixed(1)+" MPH"
    targetLabel.text=convERPMtoMPH(targetERPM).toFixed(1)+"  MPH"
     // Turn off the motor if pedal RPM less than 1 and Cruise isn't switched on
     if (Math.abs(pasPedalRPM)<1 && !cruiseToggle.checked)
        {
        if (motorRPM>0)
            {
            console.log("Setting RPM3 to:0")
            mCommands.setRpm(0)
            console.log("Setting RPM to: 0")
            }
        }
     }
 }

 // SDS - generic motor values updated in realtime
 // this is called every mainTimer.interval ms
 function onValuesReceived(values, mask)
    {
    // Update info from vesc
    motorRPM=values.rpm
    if (motorRPM>0)
        lockButton.visible=false
        else
        lockButton.visible=true

    if (motorRPM>0)
        motorTime+=mainTimer.interval/1000

    speedLabel.text=Math.abs(convERPMtoMPH(motorRPM)).toFixed(1)+" MPH"
    rpmLabel.text="ERPM: "+values.rpm.toFixed(1)

    if (motorRPM>0)
        speedLabel.color="#80ff80"
        else
        speedLabel.color="#ffffff"

    if (values.kill_sw_active)
        {
        pedalStatic=pasPedalCount
        actualERPM=0
        targetERPM=0
        errorLabel.text="Braking!!"
        errorVisible=true
        if (brakesTested==false)
            {
            brakesTested=true;
            componentsVisible=true;
            errorVisible=false;
            }
        }
        else
        {
        if (brakesTested==true)
            {
            errorLabel.text=""
            errorVisible=false;
            }
        }

    // Calc Battery stats
    batteryPercentage = 100*(values.v_in - minBattery)/(maxBattery - minBattery)
    if (batteryPercentageStart==0)
        batteryPercentageStart=batteryPercentage

    // Calc Distance Travelled and Avg speed
    var mps=convERPMtoMPH(motorRPM)/(60*60*1000/mainTimer.interval);
    distTravelled+=mps;
    var distTravelledAbs=(distTravelled/(motorTime/(60*60)));
    var batteryUsed=batteryPercentageStart-batteryPercentage;
    var distRemain = batteryPercentage/batteryUsed*distTravelledAbs;

    // circa 2025 - no battery is gonna give you 1000 miles
    if (distRemain<0) distRemain=0;
    if (distRemain>1000) distRemain=0;

    infoLabel.text="Dist: "+distTravelled.toFixed(3)+" Miles Avg: "+distTravelledAbs.toFixed(1)+" MPH Est: "+distRemain.toFixed(1)+" Miles"
    batteryLabel.text="Battery Remaining: "+(batteryPercentage).toFixed(1)+"%"+" ("+values.v_in+")"

    // Display Fault code
    if (values.fault_str!="FAULT_CODE_NONE")
        {
        errorLabel.text=values.fault_str;
        errorVisible=true;
        }
    }


 // SDS - get motor setup/config params from vesc - this runs once at app startup
 function onValuesSetupReceived(values, mask)
    {
    wheelDiameter=mMcConf.getParamDouble("si_wheel_diameter")*1000*0.0393701;
    minBattery=mMcConf.getParamDouble("l_min_vin")
    maxBattery=mMcConf.getParamDouble("l_max_vin")
    maxBattery=84 // Hardcode for more accurate readings
    console.log("onValuesSetupReceived called! "+minBattery+"v "+maxBattery+"v "+wheelDiameter+"inch")
    }

 } //connections

    id: mainItem
    anchors.fill: parent
    anchors.margins: 5
    property var bikeLocked:false
    // SDS - only lock up bike if the RPM is 0!
    function lockAPP()
    {
        if (motorRPM==0)
        {
        targetERPM=0;
        actualERPM=0;
        pedalStatic=pasPedalCount
        componentsVisible=false
        passwordVisible=true
        passwordField.text=""
        bikeLocked=true;
        }
    }


    function _onEnterPressed(event)
        {
        if (passwordField.text.length==6)
            {
            if (passwordField.text==password)
                {
                componentsVisible=true
                extrasVisible=false;
                passwordVisible=false
                bikeLocked=false;
                activeButton(2)
                }
                else
                if (passwordField.text=passwordextra)
                {
                componentsVisible=true
                extrasVisible=true;
                passwordVisible=false
                bikeLocked=false;
                }
                else
                {
                // SDS - hide the password entry for 30 secs
                passwordVisible=false;
                lockTimer.interval = 30000;
                lockTimer.repeat = false;
                lockTimer.start();
                }
            passwordField.text=""
            }
        }

    // adds a leading "0" to int to string
    // used for 00:00:00 trip time formatting

    function fmtstr(x)
        {
        var temp="%1"
        temp=temp.arg(Math.round(x));
        for (;temp.length<2;)
            temp="0"+temp;
        return temp
        }

    function changeMaxSpeed(newSpeed)
        {
        maxMPH=newSpeed

        }


    // ********************************** Timers *********************************************************
    // hides the main UI for 30 secs if password is wrong
    Timer
    {
        id: lockTimer
        repeat : false;
        interval: 30000;
        running: false;
        onTriggered: timertrigger()
        function timertrigger()
        {
        passwordVisible=true
        }
    }

    // Silly "pedal to start" text animation
    Timer
    {
        id: animTimer
        repeat: true;
        interval: 150
        running: true
        property var anim: 0
        onTriggered: {

        if (motorRPM<=0)
        {
        if (anim==0)       statusLabel.text="<<Pedal to Start>>"
        if (anim==1)       statusLabel.text="<< Pedal to Start >>"
        if (anim==2)       statusLabel.text="<<  Pedal to Start  >>"
        if (anim==3)       statusLabel.text="<<   Pedal to Start   >>"
        if (anim==4)       statusLabel.text="<<    Pedal to Start    >>"
        if (anim==5)       statusLabel.text="<<     Pedal to Start     >>"
        }
        else
         statusLabel.text="";
        anim=(anim+1)%6;
        }
    }

    Timer {
        id: mainTimer
        interval: 50 // 20hz
        repeat: true
        running: true

        onTriggered:
        {
        // SDS - trigger the send values to OnValuesReceived
        mCommands.getValues()
        // SDS - kick the motor watchDawg so the motor wont shutdown
        mCommands.sendAlive()
        if (!bikeLocked && brakesTested)
            updateMotor()

        // Update Trip Time
        if (!bikeLocked)
            {
            totalTime=totalTime+interval/1000
            tripLabel.text =  "Time: "+Qt.formatDateTime(new Date(),"hh:mm ")+" Trip: "+fmtstr(totalTime/(60*60))+":"+fmtstr((totalTime/60)%60)+":"+fmtstr(totalTime%60)
            }
       }
    }



    ColumnLayout
    {
        id: gaugeColumn
        anchors.fill: parent

        // **********************PASSWORD UI***************************************

        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
        visible : passwordVisible
        Label
            {

            text: "Startup:"
            font.pointSize : 30
            }
        }

        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
        visible : passwordVisible
        TextField
            {
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            id: passwordField
            echoMode: TextInput.Password
            maximumLength: 6
            validator: IntValidator {bottom: 1; top: 999999}
            font.pointSize : 30
            onAccepted: _onEnterPressed()
            }
        }

        // **********************Main UI***************************************
        // Horn Cruise Panic
        GroupBox {
        Layout.fillWidth: true
        visible : componentsVisible
        ColumnLayout
        {
        anchors.fill: parent
        RowLayout
        {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Button
                {
                Layout.fillWidth: true
                text: "Horn"
                onClicked: // SDS - no media libs :(
                    {
                    //myPlayer.play();
                    }
        }

        Switch // Cruise Toggle button
        {
            id: cruiseToggle
            text: "Auto"
            font.pointSize : 30
            checked:incrementalCruise
        }

        Button
        {
            Layout.fillWidth: true
            text: "Panic"
            onClicked:
            {
            targetERPM=0;
            actualERPM=0;
            pedalStatic=pasPedalCount
            mCommands.setRpm(0)
            }
        }
        }
        }
        }
// ******************************* Main speedo mph and Accel slider ***************************************
        GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
         visible : componentsVisible
        ColumnLayout
        {
        anchors.fill: parent
        RowLayout {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
                        Label {
                horizontalAlignment: Text.AlignHCenter
                id :targetLabel
                color: "#FFFFFF"
                text:"0 MPH"
                font.pointSize : 70
                }
        }

        RowLayout {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
        Label {
                horizontalAlignment: Text.AlignHCenter
                id :speedLabel
                color: "#FFFFFF"
                text: "0 MPH"
                font.pointSize : 70
                }
        }


        RowLayout {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
        Label {
                horizontalAlignment: Text.AlignHCenter
                id :rpmLabel
                color: "#8080FF"
                text: "ERPM: 0"
                font.pointSize : 30
                }
        }


        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        // s_pid_ramp_erpms_s set to 5331

        Slider
            {
            handle.implicitHeight: 34
            handle.implicitWidth: 44
            id:accelSlider
            Layout.fillWidth: true
            from: 0.01
            to: 0.35
            value: 0.1
            onValueChanged: sliderLabel.text="Accel "+value.toFixed(2)
            }
        Label
            {
            id :sliderLabel
            text: "Accel 0.10"
            font.pointSize : 20
            }
        }
}
}

// *************************** Error Status ********************************

GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible : (errorVisible)// && componentsVisible)
        ColumnLayout
        {
        anchors.fill: parent

        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
        Label {
                horizontalAlignment: Text.AlignHCenter
                id :errorLabel
                color: "#FF4000"
                text: "Brake to start"
                font.pointSize : 30
                }
        }
        }
        }

// ************************ Pedal RPM*********************************
        GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible : componentsVisible
        ColumnLayout
        {
        anchors.fill: parent

        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
        Label {
                horizontalAlignment: Text.AlignHCenter
                id :statusLabel
                color: "#FFffC0"
                text: "<<Pedal to Start>>"
                font.pointSize : 20
                }
        }
        /*
        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
        Label {
                horizontalAlignment: Text.AlignHCenter
                id :pedalLabel
                color: "#FF8080"
                text: " 0 MPH"
                font.pointSize : 20
                }
        }
        */


        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Slider
            {
            handle.implicitHeight: 34
            handle.implicitWidth: 44
            id:speedmulSlider
            Layout.fillWidth: true
            from: 0.5
            to: 2
            value: 1
            onValueChanged:
                    {
                    rpmsliderLabel.text="x "+value.toFixed(2)
                    }
            }
        Label
            {
            id :rpmsliderLabel
            text:"x "+speedmulSlider.value.toFixed(2)
            font.pointSize : 20
            }
        }
    }
}

// *********************************** Trip Info ******************************************

        GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
         visible : componentsVisible
        ColumnLayout
        {
        anchors.fill: parent
        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        Label
                {
                horizontalAlignment: Text.AlignHCenter
                id :infoLabel
                color: "#ff8f00"
                text: "Distance: 0 miles Avg Speed: 0 mph"
                font.pointSize : 20
                }
        }

        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
        Label {
                horizontalAlignment: Text.AlignHCenter
                id :batteryLabel
                color: "#ffff00"
                text: "Battery Remaining: 100%"
                font.pointSize : 20
                }
        }

        RowLayout
        {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
        Label {
                horizontalAlignment: Text.AlignHCenter
                id :tripLabel
                color: "#00ff00"
                text: "Time: 00:00 Trip Time: 00:00:00"
                font.pointSize : 20
                }
        }


}
}
// ************************* Speed/Lock Buttons ******************************************


        RowLayout
        {

                visible: componentsVisible
            Button
            {
                Layout.fillWidth: true
                id: b1
                text: "6mph" // Unicode Character 'CHECK MARK'
                onClicked:
                    {
                    changeMaxSpeed(6)
                    buttonActive(1)
                    }
            }

            Button
            {
                id:b2
                Material.background: "#008f00"
                Layout.fillWidth: true
                text: "10MPH"
                onClicked:
                {
                changeMaxSpeed(10)
                buttonActive(2)
                }
            }
            Button
            {
            id:b3
                Layout.fillWidth: true
                text: "12mph"
                onClicked:
                {
                changeMaxSpeed(12)
                buttonActive(3)
                }
            }
            Button
            {
            id:b4
                Layout.fillWidth: true
                text: "15mph"
                onClicked:
                {
                changeMaxSpeed(15)
                buttonActive(4)
                }
            }
            Button
            {
            id: lockButton
                Layout.fillWidth: true
                text: "Lock"
                onClicked:  lockAPP()
            }
        }
          RowLayout
        {

            visible: componentsVisible && extrasVisible
            Button
            {
                Layout.fillWidth: true
                id: b5
                text: "17mph" // Unicode Character 'CHECK MARK'
                onClicked:
                    {
                    changeMaxSpeed(17)
                    buttonActive(5)
                    }
            }

            Button
            {
                id:b6
                Layout.fillWidth: true
                text: "18MPH"
                onClicked:
                {
                changeMaxSpeed(18)
                buttonActive(6)
                }
            }
            Button
            {
            id:b7
                Layout.fillWidth: true
                text: "20mph"
                onClicked:
                {
                changeMaxSpeed(20)
                buttonActive(7)
                }
            }
            Button
            {
            id:b8
                Layout.fillWidth: true
                text: "30mph"
                onClicked:
                {
                changeMaxSpeed(30)
                buttonActive(8)
                }
            }

        }
    }
}
