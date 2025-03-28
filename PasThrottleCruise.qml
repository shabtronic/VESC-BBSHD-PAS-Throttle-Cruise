import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2
import Vedder.vesc.commands 1.0
import Vedder.vesc.configparams 1.0

// PAS Throttle Cruise UI
//
// (C) 2025 S.D.Smith all rights reserved

// Strictly for educational purposes only.
// Absolutely do not use this out on the road. Bench testing only!
// Use at your own *RISK* - The author accepts no liability for any damage or injuries
// if you use this software.

// 4.7kb compressed

Item {
property Commands mCommands: VescIf.commands()
property ConfigParams mMcConf: VescIf.mcConfig()
Component.onCompleted:
{
wheelDiameter=clamp(mMcConf.getParamDouble("si_wheel_diameter")*39.3701,20,30);
minBat=mMcConf.getParamDouble("l_min_vin")
maxBat=84

}

property var batcharge:[60,61.2,62.4,63.6,64.8,66.0,67.2,68.4,69.6,70.8,72,73.2,74.4,75.6,76.8,78,79.2,80.4,81.6,82.8,84]

function batPercent(v)
{
v=clamp(v,60,84);
var i=0;
for (var a=0;a<20;a++)
if (v>=batcharge[a]) i=a;
return (i+((v-batcharge[i])/(batcharge[i+1]-batcharge[i])))*5;
}

property var maxes:[2,3,4]
property var accels:[0.01,0.5,0.75]
property var curveIdx:1.0

property var colours: [Qt.vector3d(0,0,0),Qt.vector3d(0,0,0.5),Qt.vector3d(0.5,0,0),Qt.vector3d(0,0,0.0),Qt.vector3d(0,0,0),Qt.vector3d(0.5,0.5,0),Qt.vector3d(0,0,0),Qt.vector3d(0.5,0.25,0),Qt.vector3d(0,0,0),Qt.vector3d(0.0,0.0,0),Qt.vector3d(0.05,0.05,0.05),Qt.vector3d(0.15,0.15,0.15),Qt.vector3d(0.1,0.1,0.2),Qt.vector3d(0.1,0.1,0.2)]
property var colourIdx:0

property var stime:0.0
property var param1:0.0

property var gr: (8*21.9*28.0/32.0)
property var wheelDiameter: 0.0

property var pw : "353838"
property var pwextra : "353538"

property var cV: true
property var pV: false
property var exV: false
property var eV: false
property var brakesTested: true
property var plV: true

property var totalTime: 0
property var mRPM: 0
property var mTime: 0.0000001

property var maxMPH: 10
property var minMPH: 2

property var minBat:0
property var maxBat:84
property var bPCT:0
property var bPCTStart:0
property var bVolts:0;

property var distTravelled: 0

property var pRPM:0
property var pCount:0
property var cAmps:0
property var tAmps:0
property var tERPM: 0
property var aERPM: 0
property var ps:-1000000
property var zero: 0.0
property var pedalDelta:0
property var armed:true
property var trackpos:0
function clamp(v,min,max)
{
return Math.min(Math.max(v,min),max);
}

function curveMap(v)
{
v=clamp(v,0,1)
var res=v;
if (curveIdx==0) res=(Math.sin(Math.pow(v,0.5))/0.84);
if (curveIdx==2) res=(Math.sin(Math.pow(v,2.0))/0.84);
return clamp(res,0,1);
}

function updateMotor()
{
aERPM+=(tERPM-aERPM)*1.0;
mCommands.setRpm(Math.round(clamp(aERPM,0,100000)))
}

function convERPMtoMPH(erpm)
{
return (erpm/gr)*(wheelDiameter*Math.PI)/(63360/60.0)
}

function convMPHtoERPM(mph)
{
return ((mph*63360/60.0)/(wheelDiameter*Math.PI))*gr
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
else        speedButtons[a].Material.background= "#202020"
}

Connections
{
target: mCommands
function onCustomAppDataReceived(data)
{
var dv = new DataView(data, 0)
pRPM = dv.getUint8(0)-128
var pp1=dv.getUint8(1)
var pp2=dv.getUint8(2)
var pp3=dv.getUint8(3)
pCount= (pp1+(pp2*256)+(pp3*256*256))-(256*256*256/2)

var fullthrottle=(5*96*(maxMPH/10))/accels[curveIdx]
if (!bikeLocked && brakesTested==true && lockslider.active)
{
if (ps==-1000000)
ps=pCount;
pedalDelta= (pCount-ps)/fullthrottle;
if (pedalDelta<0)
{
pedalDelta=0;
ps=pCount
}
if (pedalDelta>1)
{
pedalDelta=1;
ps=pCount-(fullthrottle)
}
if (pedalDelta<0.001) pedalDelta=0;

param1=pedalDelta;
var mph=curveMap(pedalDelta)*(maxMPH-0.75);
if (mph<=0.05)mph=0;
if (mph>0.05) mph+=0.75;
if (pedalDelta>0) plV=false; else plV=true;
tERPM=convMPHtoERPM(mph)
targetLabel.text=convERPMtoMPH(tERPM).toFixed(1)+"  <MPH>"
if (pasButton.active && pRPM<1)
{
 tERPM=0;
ps=pCount
}

}
}


function onValuesReceived(values, mask)
{
mRPM=values.rpm
if (mRPM>1)
{
accelSlider.enabled=false;
lockButton.enabled=false;
enableButtons(false);
pedalMSG.visible=false;
}
else
{
pedalMSG.visible=true;
accelSlider.enabled=true;
lockButton.enabled=true;
enableButtons(true);
}

tAmps=values.current_motor;
if (tAmps<0) tAmps=0;

speedLabel.text=Math.abs(convERPMtoMPH(mRPM)).toFixed(1)+" MPH"
rpmLabel.text="ERPM: "+values.rpm.toFixed(1)

if (mRPM>0)
speedLabel.color="#80ff80"
else
speedLabel.color="#ffffff"

if (values.kill_sw_active)
{
setactive(false)
ps=pCount
aERPM=0
tERPM=0
errorLabel.color="#ffff00"
errorLabel.text="Braking!!"
eV=true
if (brakesTested==false)
{
brakesTested=true;
cV=true;
eV=false;
}
}
else
{
if (brakesTested==true)
{
errorLabel.text=""
eV=false;
}
}

bVolts=values.v_in;
bPCT = batPercent(values.v_in);
if (bPCTStart==0)
    bPCTStart=bPCT

if (values.fault_str!="FAULT_CODE_NONE")
{
errorLabel.color="#ffff00"
errorLabel.text=values.fault_str;
eV=true;
}
}
}

anchors.fill: parent
property var bikeLocked:false

function lockAPP()
{
if (mRPM==0)
{
tERPM=0;
aERPM=0;
ps=pCount
cV=false
pV=true
pwField.text=""

lockslider.value=0;
lockslider.active=false;
lockslider.lslabel.text="Slide to enable"
lockslider.lslabel.color="#808080"
bikeLocked=true;
}
}


function _onEnterPressed(exVent)
{
if (pwField.text.length==6)
{
if (pwField.text==pw)
{
cV=true
exV=false;
pV=false
bikeLocked=false;
if (maxMPH>15)
{
buttonActive(1);
maxMPH=10;
}
}
else
{
if (pwField.text==pwextra)
{
cV=true
exV=true;
pV=false
bikeLocked=false;
}
else
{
cV=false;
pV=false;
lockTimer.interval = 30000;
lockTimer.repeat = false;
lockTimer.start();
}
}
pwField.text=""
}
}

function fmtstr(x)
{
var temp="%1"
temp=x.toFixed(0);
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
onTriggered: pV=true
}

Timer {
id: motorpollTimer
interval: 100 // 10hz
repeat: true
running: true
onTriggered:
{
if (!bikeLocked && brakesTested)
updateMotor()
mCommands.getValues()
mCommands.sendAlive()
}

}

Timer {
id: gfxTimer
interval: 16
repeat: true
running: true
onTriggered:
{
stime+=interval/1000.0;
trackpos+=curveMap(pedalDelta);
if (mRPM>1)
    mTime+=gfxTimer.interval/1000

if (!bikeLocked )
{
totalTime=totalTime+interval/1000.0
tripLabel.text =  "Time: "+Qt.formatDateTime(new Date(),"hh:mm ")+"       Trip: "+fmtstr(Math.floor(totalTime/(60*60)))+":"+fmtstr(Math.floor(totalTime/60)%60)+":"+fmtstr(Math.floor(totalTime)%60)
}

distTravelled+=convERPMtoMPH(mRPM)/(60.0*60.0*1000.0/gfxTimer.interval);
var dta=(distTravelled/(mTime/(60.0*60.0)));
var distRemain = bPCT/(bPCTStart-bPCT)*dta;

if (distRemain<0) distRemain=0;
if (distRemain>1000) distRemain=0;
if (distRemain!=distRemain) distRemain=0;

infoLabel.text="Dist: "+distTravelled.toFixed(1)+" Miles      Avg: "+dta.toFixed(1)+" MPH"
batteryLabel.text="Battery: "+(bPCT).toFixed(1)+"%      Est: "+distRemain.toFixed(1)+" Miles"

ampLabel.text="Amps: "+cAmps.toFixed(1);
cAmps+=(tAmps-cAmps)*0.5;
}
}

function setactive(v)
{
}

Rectangle
{
id: background
anchors.fill: parent
color: "#000000"
}

ColumnLayout
{
anchors.fill: parent
Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
GroupBox {
Layout.fillWidth: true
Layout.fillHeight: true
//anchors.fill: parent
//height:1500

visible : pV
Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
background:Rectangle
{
layer.enabled: true;
ShaderEffect
{
blending:false
width: parent.width
height: parent.height
property var source: parent
property var time: stime
property var rx : parent.width
property var ry : parent.height
property var down: zero
property var sc: colours[colourIdx]
property var ec: colours[colourIdx+1]
fragmentShader: roundrectvgrad
}
}

RowLayout
{
Layout.fillHeight: true
Layout.fillWidth: true
Layout.alignment: Qt.AlignHCenter|Qt.AlignVCenter
visible : pV
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
visible : pV
TextField
{
horizontalAlignment: Text.AlignHCenter
Layout.fillWidth: true
id: pwField
echoMode: TextInput.Password
maximumLength: 6
validator: IntValidator {bottom: 1; top: 999999}
font.pointSize : 30
onAccepted: _onEnterPressed()
}
}

}
GroupBox {
Layout.fillWidth: true
visible : cV
background:Rectangle
{
layer.enabled: true;
ShaderEffect
{
blending:false
width: parent.width
height: parent.height
property var source: parent
property var time: stime
property var rx : parent.width
property var ry : parent.height
property var down: zero
property var sc: colours[colourIdx]
property var ec: colours[colourIdx+1]
fragmentShader: roundrectvgrad
}
}

ColumnLayout
{
anchors.fill: parent
RowLayout
{
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
property var down : uicolbutton.pressed+0.001
property var sc: colours[colourIdx]
property var ec: colours[colourIdx+1]
fragmentShader: roundrectvgrad
}
}
}

// Custom Lock Slider
Item {
    id: lockslider
    property double max:1
    property double value:0
    property double min:0
    property bool active: false
    width: 250;
    height:40
    enabled:mRPM<1
    Layout.fillWidth: true
    Rectangle {
        width: parent.width
            height: parent.height
            radius: 0.25 * height
            color: '#101010'
    }
    Rectangle {
        id: pill
        x: (parent.value - parent.min) / (parent.max - parent.min) * (lockslider.width - pill.width) // pixels from value
        width: parent.height*2;
        height: parent.height
        radius: 0.25 * height
        color:"#606060"
    }
    Label{
    id: lslabel
    Layout.fillWidth: true
    text:"Slide to enable"
    x:(parent.width-width)/2
    y:(parent.height-height)/2
    font.pointSize : 26
    color:"#808080"
    }
    MouseArea {
        id: mouseArea
        preventStealing: true
        anchors.fill: parent
        drag {
        id :did
            target:   pill
            axis:     Drag.XAxis
            maximumX: lockslider.width - pill.width
            minimumX: 0
        }
        onReleased:
            {
            parent.value=pill.x/(width-pill.width);
            if (parent.value!=1)
            {
            parent.value=0;
            lslabel.text="Slide to enable"
            lslabel.color="#808080"
            lockslider.active=false;
            ps=pCount
            aERPM=0
            tERPM=0
            }
            else
            {
            lslabel.text="Active";
            lslabel.color="#00ff00"
            lockslider.active=true;
            ps=pCount
            aERPM=0
            tERPM=0
            }
            }
    }
}



Layout.fillHeight: true
Layout.fillWidth: true
Button
{
Layout.fillWidth: true
text: "Panic"
font.pointSize : 20
id:panicbutton
onClicked:
{
tERPM=0;
aERPM=0;
ps=pCount
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
property var time: stime
property var rx : parent.width
property var ry : parent.height
property var down: panicbutton.pressed+0.001
fragmentShader: hypnoshader
}
}
}

}
}
}

GroupBox {
id:mainbox
Layout.fillWidth: true
Layout.fillHeight: true
visible : cV

background:Rectangle
{
layer.enabled: true;
ShaderEffect
{
blending:false
width: parent.width
height: parent.height
property var source: parent
property var time: stime
property var rx : parent.width
property var ry : parent.height
property var down:zero
property var p1 : trackpos;
fragmentShader: polepos
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
color: "#8080FF"
text:"Amps: 0"
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
from: 0.01
to: 1
value: 0.5
onValueChanged:
{
ps=pCount
sliderLabel.text="Accel "+value.toFixed(2)
accels[curveIdx]=value;
}
}
Label
{
id :sliderLabel
text: "Accel 0.15"
font.pointSize : 20
}
}
}
}

GroupBox {
Layout.fillWidth: true
Layout.fillHeight: true
visible : (eV)
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
property var down:zero
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

GroupBox {
Layout.fillWidth: true
Layout.fillHeight: true
visible : cV && lockslider.active
id: pedalMSG
background:Rectangle
{
layer.enabled: true;
ShaderEffect
{
blending:false
width: parent.width
height: parent.height
property var source: parent
property var time: stime
property var rx : parent.width
property var ry : parent.height
property var down:zero
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

Button
{
//Layout.fillWidth: true
text: "PAS Mode"
font.pointSize : 20
id:pasButton
property var active:false
onClicked:
{
active=!active;
if (active)
Material.background="#008f00"
else
Material.background="#202020"

}
}
Label {
horizontalAlignment: Text.AlignHCenter
id :statusLabel
color: "#FFffC0"
text: "       Pedal to Start       "
font.pointSize : 30
visible: cV && plV
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
property var time: stime
property var rx : parent.width
property var ry : parent.height
property var down:0.0001
fragmentShader: hscanner
}
}
}
}
}
}

GroupBox {
Layout.fillWidth: true
Layout.fillHeight: true
visible : cV
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
property var down: zero
property var p1 : curveMap(pedalDelta);
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
Label {
horizontalAlignment: Text.AlignHCenter
id :infoLabel
text: "Dist:"
font.pointSize : 25
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
text: "Battery:"
font.pointSize : 25
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
text: "Time: 00:00 Trip Time: 00:00:00"
font.pointSize : 25
}
}
}
}

GroupBox {
Layout.fillWidth: true
Layout.fillHeight: true
visible : cV
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
property var down:0.0001
fragmentShader: roundrectvgrad
}
}
ColumnLayout
{
anchors.fill: parent
RowLayout
{

visible: cV
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
property var time: stime
property var rx : width
property var ry : height
property var down: (lockButton.pressed+0.001)
fragmentShader: hypnoshader
}
}
}
}
RowLayout
{
visible: cV && exV
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
Button
{
id: tirebutton
text :"Wheel\n"+wheelDiameter.toFixed(1)+"\""
font.pointSize : 16
x:mainbox.x+mainbox.width/5-mainbox.width/6
y:mainbox.y+(mainbox.height-mainbox.width/5)/2
width:mainbox.width/6
height:width
visible: cV
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
property var down: zero
fragmentShader: roundrectvgrad
}
}
}

Button
{
id: curvebutton
onClicked:
    {
    if (mRPM<0.1)
    {
    curveIdx=(curveIdx+1)%3;  ps=-1000000
    accelSlider.value=accels[curveIdx];
    }
    }
x:mainbox.x+mainbox.width-mainbox.width/5
y:mainbox.y+(mainbox.height-mainbox.width/5)/2
width:mainbox.width/6
height:width
visible: cV
background:Rectangle
{
layer.enabled: true;
ShaderEffect
{
blending:false
width: parent.width
height: parent.height
property var source: parent
property var time: stime
property var rx : width
property var ry : height
property var down: (curvebutton.pressed+0.01)
property var cidx :curveIdx+0.01
property var p1 : param1
fragmentShader: curves
}
}
}


property var shdr : "varying highp vec2 qt_TexCoord0;
uniform highp float time;
uniform highp float rx;
uniform highp float ry;
uniform highp float down;
uniform highp float cidx;
uniform highp vec3 sc;
uniform highp vec3 ec;
uniform highp float p1;
#define tc qt_TexCoord0
#define gfc gl_FragColor
float sdBox(vec2 p,vec2 b )
{
vec2 d=abs(p)-b;
return length(max(d,0.0))+min(max(d.x,d.y),0.0);
}
"

property var hypnoshader:shdr+"
void main()
{
vec2 ss=(tc-0.5)*vec2(rx,ry);
float r=min(min(10.0,rx/2.0),ry/2.0);
float d=-(sdBox(ss,vec2(rx-r*2.0,ry-r*2.0)/2.0)-r);
float a=smoothstep(0.0-1.0,0.0+1.0,d);
float t=(time*5.0+down*1234.0)/3.0;
vec2 c=(tc*2.0-1.0)*vec2(rx/ry,1.0)/3.0;
float s=(sin(sqrt(c.x*c.x+c.y*c.y)*10.0-(t*1.0))/sqrt(c.x*c.x+c.y*c.y))*0.5+0.5;
vec3 co=vec3(c.x*0.5+0.5,0.0,c.y*0.25+0.85);
if (d<2.0) {co+=vec3(0.5);s=1.0;}
gfc=vec4(co*s*a,a);
}"

property var hscanner:shdr+"
void main()
{
float t=time*5.0;
vec2 c=(tc*2.0-1.0)*vec2(rx/ry,1.0)/3.0;
float s=cos(t)*0.3+0.5;
vec3 co=vec3(0.0);
float cc=1.0-abs(s-tc.x)/0.2;
cc=cc*(1.0-abs((tc.y-0.5))*2.0);
if (abs(s-tc.x)<0.2)
co=vec3(1.0,cc*cc*2.0,cc);
gfc=vec4(co*cc,cc);
}"

property var roundrectvgrad:shdr+"
void main()
{
vec2 ss=(tc-0.5)*vec2(rx,ry);
float r=min(min(15.0,rx/2.0),ry/2.0);
float d=-(sdBox(ss,vec2(rx-r*2.0,ry-r*2.0)/2.0)-r);
float a=smoothstep(0.5-1.0,0.5+1.0,d);
vec3 c=mix(sc,ec,tc.y);
if (d<4.0) c+=0.04;
c+=down;
gfc=vec4(c*a,a);
}"

property var curves:shdr+"
float curveMap(float v)
{
if (cidx==0.01) return (sin(pow(v,0.5))/0.84);
if (cidx==1.01) return (v);
return (sin(pow(v,2.0))/0.84);
}
void main( void )
{
vec2 ss=(tc-0.5)*vec2(rx,ry);
float r=min(min(15.0,rx/2.0),ry/2.0);
float d=-(sdBox(ss,vec2(rx-r*2.0,ry-r*2.0)/2.0)-r);
float a=smoothstep(0.5-1.0,0.5+1.0,d);
vec2 p=tc*2.0-1.0;
p.y=-p.y;
float c=0.0;
float dd=((curveMap((p.x/2.0)+0.5)*2.0-1.0)-p.y);
float fd=10.0/pow(rx,0.85);
c=((1.0-smoothstep(0.0-fd,0.0+fd,abs(dd)))*10.0)+0.1;
vec2 dp=vec2(p1*2.0-1.0,curveMap(p1)*2.0-1.0);
float c2=pow(clamp(1.0-length(p-dp)*1.0,0.0,1.0),3.0);
if (p.x<dp.x && dd>0.0) c+=0.9;
if (d<4.0) {c=1.5;c2=0.0;}
c+=down*4.0;
gfc=vec4((vec3(0.2, 0.2, 0.2)*c+vec3(0.0,1.8,0.0)*c2)*a,a);
}"
property var polepos:shdr+"// https://www.glslsandbox.com/e#109581.0
vec3 road(vec3 p)
{
vec3 c1=vec3(0.1,0.9,0.1);
vec3 c2=vec3(0.1,0.6,0.1);
float k=sin(0.2*p1/15.0);
p.x *=p.x-=.05*k*k*k*p.y*p.y;
if(abs(p.x)<1.0)
{
c1=vec3(0.9,0.1,0.1);
c2=vec3(0.9,0.9,0.9);
}
if(abs(p.x)<.8)
{
c1=vec3(0.5,0.5,0.5);
c2=vec3(0.5,0.5,0.5);
}
if(abs(p.x)<0.002)
{
c1=vec3(0.5,0.5,0.5);
c2=vec3(0.9,0.9,0.9);
}
float t=p1/5.0;
float v=pow(sin(0.0),20.0);
float r=fract(p.y+t);
float b=dot(p,p)*0.005;
vec3 g=mix(c1,c2,smoothstep(0.25-b*0.25,0.25+b*0.25,r)*smoothstep(0.75+b*0.25,0.75-b*0.25,r));
return g;
}

void main( void )
{
vec2 res=vec2(rx,ry)/ry;
vec2 uv=vec2(1.0,-1.0)*(tc*2.0-1.0);
vec3 p=vec3(uv.x/abs(uv.y),1.0/abs(uv.y),step(0.0,uv.y)*2.0-1.0);
vec3 c=0.25*mix(road(p),mix(vec3(1.0,1.0,1.0),vec3(0.1,0.7,1.0),uv.y),step(.0,p.z));
vec2 ss=(tc-0.5)*vec2(rx,ry);
float r=min(min(15.0,rx/2.0),ry/2.0);
float d=-(sdBox(ss,vec2(rx-r*2.0,ry-r*2.0)/2.0)-r);
float a=smoothstep(0.5-1.0,0.5+1.0,d);
if (d<4.0) c=vec3(0.5);
gfc=vec4(c*a,a);
}
"
}
