import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import Vedder.vesc.utility 1.0
import Vedder.vesc.commands 1.0
import Vedder.vesc.configparams 1.0

// PAS Throttle Cruise UI
//
// (C) 2025 S.D.Smith all rights reserved

Item {

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

    property var drawshaders:true
    property var shadertime:0
    property var param1:0

    property var motormagnets: 8
    property var motorratio: 21.9
    property var crankgear: 28
    property var wheelgear: 32
    property var gearRatio: (motormagnets*motorratio*wheelgear/crankgear) // convert to and from ERPM/MPH

    property var wheelDiameter: 28.5 // inches - fat bike 26" + stupidly big tyres = 28.5"!!

    property var incrementalCruise: true; // enable/disable cruise

    // Change to whatever you like!
    property var password : "353838"
    // unlock "extra speeds"
    property var passwordextra : "353538"

    property var componentsVisible: true // set to false for brake test
    property var passwordVisible: false
    property var extrasVisible: false
    property var errorVisible: false // set to true for brake test
    property var brakesTested: true // set to false for brake test
    property var pedallabelVisible: true
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

    function curveMap(param)
    {
        if (param<0) param=0;
        if (param>1) param=1;
        return Math.tanh(Math.PI*(param*2-1))*0.5+0.5;
    }
    function updateMotor()
    {
        // SDS - simple 6db lpf - probably the wrong thing to use
        actualERPM+=(targetERPM-actualERPM)*0.9;
        if (actualERPM>=0 && actualERPM<70000)
           mCommands.setRpm(Math.round(actualERPM))
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

        // Extend out the turns for higher max speeds
        var baselineratio=maxMPH/10
        // calculate pedal count for max speed
        var fullthrottle=(5*96*baselineratio)/accelSlider.value

        if (!bikeLocked && brakesTested==true)
        {
        // Calculate target speed from pedalcount
        if (pedalStatic==-1000000)
            pedalStatic=pasPedalCount;
        var pedalDelta=0;
        if (pedalStatic!=-1000000)
            {
            pedalDelta= (pasPedalCount-pedalStatic)/fullthrottle;
            if (pedalDelta<0)
                {
                pedalDelta=0;
                pedalStatic=pasPedalCount
                }
            if (pedalDelta>1)
                {
                pedalDelta=1;
                pedalStatic=pasPedalCount-(fullthrottle)
                }
            // SDS - much simpler and smoother accel curve
            param1=pedalDelta;
            var mph=curveMap(pedalDelta)*(maxMPH-0.75);
            if (mph<=0.05)mph=0;
            if (mph>0.05) mph+=0.75;
           if (pedalDelta>0)
            pedallabelVisible=false
            else
            pedallabelVisible=true
            targetERPM=convMPHtoERPM(mph)
            }
            else
            {
            pedalDelta=0;
            }

     pedalLabel.text= "Delta "+(pedalDelta).toFixed(3)+" MPH"
     targetLabel.text=convERPMtoMPH(targetERPM).toFixed(1)+"  <MPH>"
     // Turn off the motor if pedal RPM less than 1 and Cruise isn't switched on
     if (Math.abs(pasPedalRPM)<1 && !cruiseToggle.checked)
        {
        if (motorRPM>0)
            {
            targetERPM=0;
            actualERPM=0;
            mCommands.setRpm(0)
            }
        }
     }
 }

 function onValuesReceived(values, mask)
    {
    // Update info from vesc
    motorRPM=values.rpm

    if (motorRPM>1)
        {
        motorTime+=mainTimer.interval/1000
        accelSlider.enabled=false;
        lockButton.enabled=false;
        }
    else
        {
        accelSlider.enabled=true;
        lockButton.enabled=true;
        }

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
        errorLabel.color="#ffff00"
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
    }

 } //connections

    id: mainItem
    anchors.fill: parent
    anchors.margins: 5
    property var bikeLocked:false

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
                passwordVisible=false;
                lockTimer.interval = 30000;
                lockTimer.repeat = false;
                lockTimer.start();
                }
            passwordField.text=""
            }
        }

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
        if (newSpeed>30) newSpeed=30;
        if (newSpeed<6) newSpeed=6;
        maxMPH=newSpeed
        // pedalStatic=pasPedalCount
        }

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


    Timer {
        id: mainTimer
        interval: 16 // 60hz
        repeat: true
        running: true

        onTriggered:
        {
        shadertime+=1.0/interval;
        mCommands.getValues()
        mCommands.sendAlive()
        if (!bikeLocked && brakesTested)
            updateMotor()
        if (!bikeLocked)
            {
            totalTime=totalTime+interval/1000
            tripLabel.text =  "Time: "+Qt.formatDateTime(new Date(),"hh:mm ")+" Trip: "+fmtstr(totalTime/(60*60))+":"+fmtstr((totalTime/60)%60)+":"+fmtstr(totalTime%60)
            }
       }
    }

    Rectangle
    {
        id: background
        anchors.fill: parent
        color: "#202020"
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
        background:Rectangle
                    {
                    opacity: 1/257
                    ShaderEffect
                    {
                    width: parent.width
                    height: parent.height
                    property var source: parent
                    property var time: shadertime // update shadertime in a timer
                    property var resx : parent.width
                    property var resy : parent.height
                    visible: drawshaders
                    fragmentShader: roundrectvgrad
                    }
                    }
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
                onClicked:
                    {
                    }
        }

        Switch
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
            font.pointSize : 20
            onClicked:
            {
            targetERPM=0;
            actualERPM=0;
            pedalStatic=pasPedalCount
            mCommands.setRpm(0)
            console.log("Panic pressed!")
            }
        background:Rectangle
            {
            opacity: 1/257
            ShaderEffect
                {
                width: parent.width
                height: parent.height
                property var source: parent
                property var time: shadertime
                property var resx : parent.width
                property var resy : parent.height
                visible: drawshaders
                fragmentShader: hypnoshader
                }
        }
        }
        }
        }
        }
// ******************************* Main speedo mph and Accel slider ***************************************
        GroupBox {
        id:mainbox
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible : componentsVisible
        // SDS - coz shaders are important! :)
        background:Rectangle
        {
        opacity: 1/257
        ShaderEffect
            {
            width: parent.width
            height: parent.height
            property var source: parent
            property var time: shadertime // update shadertime in a timer
            property var resx : parent.width
            property var resy : parent.height
            visible: drawshaders
            fragmentShader: roundrectvgrad
            }
        }
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
        Slider
            {
            handle.implicitHeight: 34
            handle.implicitWidth: 44
            id:accelSlider
            Layout.fillWidth: true
            from: 0
            to: 2
            value: 1
            onValueChanged:
            {
            pedalStatic=pasPedalCount
            sliderLabel.text="Accel "+value.toFixed(2)
            }
            }
        Label
            {
            id :sliderLabel
            text: "Accel 1.00"
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
        background:Rectangle
                    {
                    opacity: 1/257
                    ShaderEffect
                    {
                    width: parent.width
                    height: parent.height
                    property var source: parent
                    property var time: shadertime // update shadertime in a timer
                    property var resx : parent.width
                    property var resy : parent.height
                    visible: drawshaders
                    fragmentShader: hypnoshader
                    }
                    }
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
                background:Rectangle
        {
        opacity: 1/257
        ShaderEffect
            {
            width: parent.width
            height: parent.height
            property var source: parent
            property var time: shadertime // update shadertime in a timer
            property var resx : parent.width
            property var resy : parent.height
            visible: drawshaders
            fragmentShader: roundrectvgrad
            }
        }
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
                text: "       Pedal to Start       "
                font.pointSize : 20
                visible: componentsVisible && pedallabelVisible
                background:Rectangle
                    {
                    opacity: 1/257
                    ShaderEffect
                    {
                    width: parent.width
                    height: parent.height
                    property var source: parent
                    property var time: shadertime // update shadertime in a timer
                    property var resx : parent.width
                    property var resy : parent.height
                    visible: drawshaders
                    fragmentShader: hscanner
                    }
            }
                }
        }

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
    }
}

// *********************************** Trip Info ******************************************
        GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
         visible : componentsVisible
        background:Rectangle
        {
        opacity: 1/257
        ShaderEffect
            {
            width: parent.width
            height: parent.height
            property var source: parent
            property var time: shadertime // update shadertime in a timer
            property var resx : parent.width
            property var resy : parent.height
            property var startcol: Qt.vector3d(0,0,0)
            property var endcol: Qt.vector3d(0,0,0.3)
            visible: drawshaders
            fragmentShader: roundrectvgrad
            }
        }
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
                font.pointSize : 20
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
                font.pointSize : 20
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
            font.pointSize : 20
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
            font.pointSize : 20
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
            font.pointSize : 20
            onClicked:  lockAPP()

            background:Rectangle
            {
            ShaderEffect
                {
                width: parent.width
                height: parent.height
                property var source: parent
                property var time: shadertime // update shadertime in a timer
                property var resx : width
                property var resy : height
                visible: drawshaders
                fragmentShader: hypnoshader
                }
            }
            }
        }
        // passwordExtra buttons
        RowLayout
        {
            visible: componentsVisible && extrasVisible
            Button
            {
                Layout.fillWidth: true
                id: b5
                font.pointSize : 20
                text: "17mph"
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
                font.pointSize : 20
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
                font.pointSize : 20
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
                font.pointSize : 20
                onClicked:
                {
                changeMaxSpeed(30)
                buttonActive(8)
                }

            }

        }
    }

    Rectangle
    {
    x:mainbox.x+mainbox.width-mainbox.width/4.5
    y:mainbox.y+(mainbox.height-mainbox.width/5)/2
    width:mainbox.width/5
    height:width
    visible: componentsVisible
    opacity:0.5
                ShaderEffect
                {
                width: parent.width
                height: parent.height
                property var source: parent
                property var time: shadertime
                property var resx : width
                property var resy : height
                property var glparam1:param1
                visible: true
                fragmentShader: sigmoid
                }
     }



property var solidcolor: "varying highp vec2 qt_TexCoord0;
                            uniform highp float time;
                            void main()
                            {
                            gl_FragColor = vec4(0.0,0.0,mod(qt_TexCoord0.y+time,1.0),1.0);
                            }
                            "
property var hypnoshader:   "varying highp vec2 qt_TexCoord0;
                            uniform highp float time;
                            uniform highp float resx;
                            uniform highp float resy;
                            void main()
                            {
                            float t = time/3.0;
                            vec2 coords = ((qt_TexCoord0) * 2.0 - 1.0)*vec2(resx/resy,1.0)/3.0;
                            float x = coords.x;
                            float y = coords.y;
                            float s = (sin(sqrt(x*x + y*y) * 10.0 - (time * 1.0)) / sqrt(x*x + y*y)) * 0.5 + 0.5;
                            vec3 color = vec3(x * 0.5 + 0.5, 0.0, (y) * 0.5 + 0.85);
                            gl_FragColor = vec4(color * s,  1.0);
                            }"

property var hscanner:   "varying highp vec2 qt_TexCoord0;
                            uniform highp float time;
                            uniform highp float resx;
                            uniform highp float resy;
                            void main()
                            {
                            float t = time;
                            vec2 coords = ((qt_TexCoord0) * 2.0 - 1.0)*vec2(resx/resy,1.0)/3.0;
                            float x = coords.x*3.0;
                            float y = coords.y;
                            float s = (cos(t)*0.3+0.5);
                            vec3 color = vec3(0.0);
                            float cc=1.0-abs(s-qt_TexCoord0.x)/0.2;
                            cc=cc*(1.0-abs((qt_TexCoord0.y-0.5))*2.0);
                            if (abs(s-qt_TexCoord0.x)<0.2)
                            color=vec3(0.0,cc*4.0,cc);
                            gl_FragColor = vec4(color ,  1.0);
                            }"

property var roundrectvgrad:"varying highp vec2 qt_TexCoord0;
                            uniform highp float time;
                            uniform highp float resx;
                            uniform highp float resy;
                            uniform highp vec3 startcol;
                            uniform highp vec3 endcol;
                            float sdBox(vec2 p,vec2 b )
                            {
                            vec2 d = abs(p)-b;
                            return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
                            }
                            void main()
                            {
                            vec2 sspace=(qt_TexCoord0-0.5)*vec2(resx,resy);
                            float rad=min(min(20.0,resx/2.0),resy/2.0);
                            float d=-(sdBox(sspace,vec2(resx-rad*2.0,resy-rad*2.0)/2.0)-rad);
                            float xx=1.0;
                            float alpha=smoothstep(0.5-xx,0.5+xx,d);
                            vec3 color = mix(startcol,endcol,qt_TexCoord0.y);
                            gl_FragColor = vec4(color ,  alpha);
                            }"
property var sigmoid: "varying highp vec2 qt_TexCoord0;
                            uniform highp float time;
                            uniform highp float glparam1;
                            uniform highp float resx;
                            uniform highp float resy;
                            float tanh(float v)
                            {
                            return (exp(v)-exp(-v))/(exp(v)+exp(-v));
                            }
                            void main( void )
                            {
                            vec2 pos = ( qt_TexCoord0 ) *2.0-1.0;
                            pos.y=-pos.y;
                            float color = 0.0;
                            float dd=abs(tanh(pos.x*3.1415)-pos.y);
                            float fd=10.0/resx;
                            color=1.0-smoothstep(0.0-fd,0.0+fd,dd);
                            color+=0.1;
                            float tm=mod(time/4.0, 1.0)*2.0-1.0;
                            vec2 dp=vec2(glparam1*2.0-1.0,tanh((glparam1*2.0-1.0)*3.1415));
                            float color2=clamp(1.0-length(pos-dp)*4.1, 0.0, 1.0);
                            gl_FragColor = vec4( vec3(0.2, 0.2, 0.2)* color +vec3(1.0,0.8,0)*color2, 1.0 );
                            }
                            "
}
