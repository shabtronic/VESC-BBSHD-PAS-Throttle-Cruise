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

// Strictly for educational purposes only.
// Absolutely do not use this out on the road. Bench testing only!
// Use at your own *RISK* - The author accepts no liability for any damage or injuries
// if you use this software.

Item {

    property Commands mCommands: VescIf.commands()
    property ConfigParams mMcConf: VescIf.mcConfig()

    Component.onCompleted:
    {
        mCommands.emitEmptySetupValues()
    }
    property var colours: [Qt.vector3d(0,0,0),Qt.vector3d(0,0,0.5),Qt.vector3d(0.5,0,0),Qt.vector3d(0,0,0.0),Qt.vector3d(0,0,0),Qt.vector3d(0.5,0.5,0),Qt.vector3d(0,0,0),Qt.vector3d(0.5,0.25,0),Qt.vector3d(0,0,0),Qt.vector3d(0.0,0.0,0),Qt.vector3d(0.05,0.05,0.05),Qt.vector3d(0.15,0.15,0.15),Qt.vector3d(0.1,0.1,0.2),Qt.vector3d(0.1,0.1,0.2)]
    property var curColour:0

    property var drawshaders:true
    property var shadertime:0
    property var param1:0

    property var gearRatio: (8*21.9*28/32)
    property var wheelDiameter: 28.5

    property var password : "353838"
    property var passwordextra : "353538"

    property var componentsVisible: true
    property var passwordVisible: false
    property var extrasVisible: false
    property var errorVisible: false
    property var brakesTested: true
    property var pedallabelVisible: true
    // Various
    property var totalTime: 0
    property var motorRPM: 0
    property var motorTime: 0.0000001
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
        actualERPM+=(targetERPM-actualERPM)*0.975;
        if (actualERPM>=0 && actualERPM<70000)
           mCommands.setRpm(Math.round(actualERPM))
    }

    function convERPMtoMPH(erpm)
    {
         return erpm/((63360/(wheelDiameter*Math.PI*60.0))*gearRatio)
    }

    function convMPHtoERPM(mph)
    {
        return (mph*63360/(wheelDiameter*Math.PI*60.0))*gearRatio
    }

    property var speedButtons: [b1,b2,b3,b4,b5,b6,b7,b8]

    function enableButtons(value)
    {
        for (var a=0;a<8;a++)
            speedButtons[a].enabled=value
    }

    function buttonActive(idx)
    {
    for (var a=0;a<8;a++)
    if (idx==a )speedButtons[a].Material.background= "#008f00"
    else        speedButtons[a].Material.background= "#404040"
    }

 Connections
 {
 property Commands mCommands: VescIf.commands()
 property ConfigParams mMcConf: VescIf.mcConfig()
 target: mCommands

 function onCustomAppDataReceived(data)
 {
   var dv = new DataView(data, 0)
   pasPedalRPM = dv.getUint8(0)-128
   var paspc1=dv.getUint8(1)
   var paspc2=dv.getUint8(2)
   var paspc3=dv.getUint8(3)
   pasPedalCount= (paspc1+(paspc2*256)+(paspc3*256*256))-(256*256*256/2)

    var baselineratio=maxMPH/10

    var fullthrottle=(5*96*baselineratio)/accelSlider.value

    if (!bikeLocked && brakesTested==true)
    {

    if (pedalStatic==-1000000)
        pedalStatic=pasPedalCount;
    var pedalDelta=0;

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

    param1=pedalDelta;
    var mph=curveMap(pedalDelta)*(maxMPH-0.75);
    if (mph<=0.05)mph=0;
    if (mph>0.05) mph+=0.75;
   if (pedalDelta>0)
        pedallabelVisible=false
        else
        pedallabelVisible=true
     targetERPM=convMPHtoERPM(mph)
     pedalLabel.text= "Delta "+(pedalDelta).toFixed(3)+" MPH"
     targetLabel.text=convERPMtoMPH(targetERPM).toFixed(1)+"  <MPH>"
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
        enableButtons(false);
        }
    else
        {
        accelSlider.enabled=true;
        lockButton.enabled=true;
        enableButtons(true);
        }
    ampLabel.text=values.current_motor.toFixed(0)+" Amps";
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
    batteryLabel.text="Battery: "+(batteryPercentage).toFixed(1)+"%"+" ("+values.v_in+")"

    // Display Fault code
    if (values.fault_str!="FAULT_CODE_NONE")
        {
        errorLabel.color="#ffff00"
        errorLabel.text=values.fault_str;
        errorVisible=true;
        }
    }

 function onValuesSetupReceived(values, mask)
    {
    wheelDiameter=mMcConf.getParamDouble("si_wheel_diameter")*1000*0.0393701;
    minBattery=mMcConf.getParamDouble("l_min_vin")
    maxBattery=84
    }
 }

    anchors.fill: parent
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
                if (maxMPH>15)
                    {
                    buttonActive(1);
                    maxMPH=10;
                    }
                }
                else
                {
                if (passwordField.text==passwordextra)
                {
                componentsVisible=true
                extrasVisible=true;
                passwordVisible=false
                bikeLocked=false;
                }
                else
                {
                componentsVisible=false;
                passwordVisible=false;
                lockTimer.interval = 30000;
                lockTimer.repeat = false;
                lockTimer.start();
                }
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
        }

    Timer {
        id: lockTimer
        repeat : false;
        interval: 30000;
        running: false;
        onTriggered: passwordVisible=true
    }

    Timer {
        id: mainTimer
        interval: 16
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
color: "#000000"
}

    ColumnLayout
    {
        id: gaugeColumn
        anchors.fill: parent
        // PASSWORD UI***************************************
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

        // Main UI***************************************
        GroupBox {
        Layout.fillWidth: true
        visible : componentsVisible
        background:Rectangle
                    {
                    //opacity: 1
                    //color:"#000000"
                    layer.enabled: true;
                    ShaderEffect
                    {
                    blending:false
                    width: parent.width
                    height: parent.height
                    property var source: parent
                    property var time: shadertime
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


        Button
        {
            Layout.fillWidth: true
            text: "Panic"
            font.pointSize : 20
            id:panicbutton
            onClicked:
            {
            targetERPM=0;
            actualERPM=0;
            pedalStatic=pasPedalCount
            mCommands.setRpm(0)
            console.log("Panic clicked!")
         }

        background:Rectangle
            {
            layer.enabled: true;
            ShaderEffect
                {
                blending:false
                width: parent.width
                height: parent.height
                property var source: parent
                property var time: shadertime
                property var resx : parent.width
                property var resy : parent.height
                //property var buttondown: panicbutton.pressed
                visible: drawshaders
                fragmentShader: hypnoshader
                }
        }
        }
        Button
        {
            Layout.fillWidth: true
            text: "UI Col"
            onClicked:
            {
            curColour=(curColour+2)%colours.length;
            }
        }
        }
        }
        }
// Main speedo mph and Accel slider ***************************************
        GroupBox {
        id:mainbox
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible : componentsVisible

        background:Rectangle
        {
        layer.enabled: true;
        ShaderEffect
            {
            blending:false
            width: parent.width
            height: parent.height
            property var source: parent
            property var time: shadertime
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
                id :ampLabel
                color: "#FFFFFF"
                text:"0 Amps"
                font.pointSize : 35
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

// Error Status ********************************
GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible : (errorVisible)
        background:Rectangle
                    {
                    layer.enabled: true;
                    ShaderEffect
                    {
                    blending:false;
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

// Pedal RPM*********************************
        GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible : componentsVisible
        background:Rectangle
        {
        layer.enabled: true;
        ShaderEffect
            {
            blending:false
            width: parent.width
            height: parent.height
            property var source: parent
            property var time: shadertime
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
                    id:rect
                    layer.enabled: true;
                    ShaderEffect
                    {
                    blending:false
                    width: parent.width
                    height: parent.height
                    property var source: parent
                    property var time: shadertime
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
                text: "Delta 0 MPH"
                font.pointSize : 20
                }
        }
    }
}

// Trip Info ******************************************
        GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
         visible : componentsVisible
        background:Rectangle
        {
        layer.enabled: true;
        ShaderEffect
            {
            blending:false;
            width: parent.width
            height: parent.height
            property var source: parent
            property var time: shadertime
            property var resx : parent.width
            property var resy : parent.height
            property var startcol: colours[curColour]
            property var endcol: colours[curColour+1]
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
                text: "Dist: 0 miles Avg Speed: 0 mph"
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
                text: "Battery: 100% (84.0) Est: 0 Miles"
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
// Speed/Lock Buttons ******************************************
        GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
         visible : componentsVisible
        background:Rectangle
        {
        layer.enabled: true;
        ShaderEffect
            {
            blending:false;
            width: parent.width
            height: parent.height
            property var source: parent
            property var time: shadertime
            property var resx : parent.width
            property var resy : parent.height
            property var startcol: colours[curColour]
            property var endcol: colours[curColour+1]
            visible: drawshaders
            fragmentShader: roundrectvgrad
            }
        }
        ColumnLayout
        {
        anchors.fill: parent
        RowLayout
        {

            visible: componentsVisible
            Button
            {
                Layout.fillWidth: true
                id: b1
                font.pointSize : 20
                text: "6mph"
                onClicked:
                    {
                    changeMaxSpeed(6)
                    buttonActive(0)
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
                buttonActive(1)
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
                buttonActive(2)
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
                buttonActive(3)
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
            layer.enabled: true
            ShaderEffect
                {
                blending: false
                width: parent.width
                height: parent.height
                property var source: parent
                property var time: shadertime
                property var resx : width
                property var resy : height
                //property var buttondown: lockButton.pressed
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
                    buttonActive(4)
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
                buttonActive(5)
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
                buttonActive(6)
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
                buttonActive(7)
                }

            }

        }
    }
}
}
Rectangle
{
x:mainbox.x+mainbox.width-mainbox.width/5
y:mainbox.y+(mainbox.height-mainbox.width/5)/2
width:mainbox.width/6
height:width
visible: componentsVisible
opacity:1
layer.enabled: true;
ShaderEffect
    {
    blending:false
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

property var shdr : "varying highp vec2 qt_TexCoord0;
uniform highp float time;
uniform highp float resx;
uniform highp float resy;"

property var hypnoshader:shdr+"
//uniform highp int buttondown;
float sdBox(vec2 p,vec2 b )
{
vec2 d = abs(p)-b;
return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}
void main()
{
vec2 sspace=(qt_TexCoord0-0.5)*vec2(resx,resy);
float rad=min(min(10.0,resx/2.0),resy/2.0);
float d=-(sdBox(sspace,vec2(resx-rad*2.0,resy-rad*2.0)/2.0)-rad);
float alpha=smoothstep(0.0-1.0,0.0+1.0,d);
float xt=(time);
float t = xt/3.0;
vec2 c = ((qt_TexCoord0)*2.0-1.0)*vec2(resx/resy,1.0)/3.0;
float s = (sin(sqrt(c.x*c.x + c.y*c.y)*10.0-(xt*1.0)) / sqrt(c.x*c.x+c.y*c.y))*0.5+0.5;
vec3 color = vec3(c.x*0.5+0.5,0.0,(c.y)*0.25+0.85);
if (d<2.0) {color+=vec3(0.5);s=1.0;}
gl_FragColor = vec4(color * s*alpha, alpha);
}"

property var hscanner:shdr+"
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
color=vec3(1.0,cc*cc*2.0,cc);
gl_FragColor = vec4(color*cc,cc);
}"

property var roundrectvgrad:shdr+"
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
float rad=min(min(15.0,resx/2.0),resy/2.0);
float d=-(sdBox(sspace,vec2(resx-rad*2.0,resy-rad*2.0)/2.0)-rad);
float alpha=smoothstep(0.5-1.0,0.5+1.0,d);
vec3 color = mix(startcol,endcol,qt_TexCoord0.y);
if (d<4.0) color+=0.1;
gl_FragColor = vec4(color*alpha ,  alpha);
}"

property var sigmoid:shdr+"uniform highp float glparam1;
float sdBox(vec2 p,vec2 b )
{
vec2 d = abs(p)-b;
return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}
float tanh(float v)
{
return (exp(v)-exp(-v))/(exp(v)+exp(-v));
}
void main( void )
{
vec2 sspace=(qt_TexCoord0-0.5)*vec2(resx,resy);
float rad=min(min(15.0,resx/2.0),resy/2.0);
float d=-(sdBox(sspace,vec2(resx-rad*2.0,resy-rad*2.0)/2.0)-rad);
float alpha=smoothstep(0.5-1.0,0.5+1.0,d);
vec2 pos = ( qt_TexCoord0 ) *2.0-1.0;
pos.y=-pos.y;
float color = 0.0;
float dd=abs(tanh(pos.x*3.1415)*0.8-pos.y);
float fd=10.0/resx;
color=(1.0-smoothstep(0.0-fd,0.0+fd,dd))*10.0;
color+=0.1;
float tm=mod(time/4.0, 1.0)*2.0-1.0;
vec2 dp=vec2(glparam1*2.0-1.0,tanh((glparam1*2.0-1.0)*3.1415)*0.8);
float color2=clamp(1.0-length(pos-dp)*2.0, 0.0, 1.0);
if (d<4.0) {color=0.5;color2=0.0;}
gl_FragColor = vec4( (vec3(0.2, 0.2, 0.2)* color +vec3(1.0,0.8,0)*color2)*alpha,alpha);
}"
}
