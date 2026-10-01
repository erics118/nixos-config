// osascript is Apple-signed, so CoreWiFi returns network names without location access
// with the argument "cached" it returns the system's recent scan results instead of scanning
ObjC.import("CoreWLAN");
$.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/CoreWiFi.framework").load;

function run(argv) {
    const known = new Set();
    const profiles = $.CWWiFiClient.sharedWiFiClient.interface.configuration.networkProfiles.array;
    for (let i = 0; i < profiles.count; i++) {
        known.add(ObjC.unwrap(profiles.objectAtIndex(i).ssid));
    }

    const wifi = $.NSClassFromString("CWFInterface").alloc.init;
    wifi.activate;

    const params = $.NSClassFromString("CWFScanParameters").alloc.init;
    params.setCacheOnly(argv[0] === "cached");
    const results = wifi.performScanWithParametersError(params, null);

    // one entry per network name, keeping its strongest access point
    const networks = {};
    for (let i = 0; !results.isNil() && i < results.count; i++) {
        const result = results.objectAtIndex(i);
        const name = ObjC.unwrap(result.networkName);
        const strength = ObjC.unwrap(result.signalStrength);
        if (!name || (networks[name] && networks[name].strength >= strength)) {
            continue;
        }
        networks[name] = {
            name: name,
            strength: strength,
            secure: !result.isOpen,
            known: known.has(name),
            hotspot: result.isPersonalHotspot,
        };
    }

    return JSON.stringify(Object.values(networks).sort((a, b) => b.strength - a.strength));
}
