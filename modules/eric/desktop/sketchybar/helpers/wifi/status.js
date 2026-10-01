// osascript is Apple-signed, so CoreWiFi returns the network name without location access
$.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/CoreWiFi.framework").load;

const wifi = $.NSClassFromString("CWFInterface").alloc.init;
wifi.activate;

const current = wifi.currentScanResult;

JSON.stringify({
    power: wifi.powerOn,
    name: ObjC.unwrap(wifi.networkName) || "",
    strength: current.isNil() ? 0 : ObjC.unwrap(current.signalStrength),
});
