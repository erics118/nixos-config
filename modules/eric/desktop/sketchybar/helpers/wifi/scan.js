// on macOS 27.2 CoreWLAN's cached scan results still carry network names for osascript; CoreWiFi's do not
// CoreWiFi scans the radio more fully than CoreWLAN, and its results land in that cache
// with the argument "cached" it returns the system's recent scan results instead of scanning
ObjC.import("CoreWLAN");
$.NSBundle.bundleWithPath(
  "/System/Library/PrivateFrameworks/CoreWiFi.framework",
).load;

function run(argv) {
  if (argv[0] !== "cached") {
    const scanner =
      $.NSClassFromString("CWFInterface").alloc.initWithServiceType(5);
    scanner.activate;
    const params = $.NSClassFromString("CWFScanParameters").alloc.init;
    scanner.performScanWithParametersError(params, null);
  }

  const wifi = $.CWWiFiClient.sharedWiFiClient.interface;

  const known = new Set();
  const profiles = wifi.configuration.networkProfiles.array;
  for (let i = 0; i < profiles.count; i++) {
    known.add(ObjC.unwrap(profiles.objectAtIndex(i).ssid));
  }

  const set = wifi.cachedScanResults;
  const results = set.isNil() ? [] : ObjC.unwrap(set.allObjects);

  // one entry per network name, keeping its strongest access point
  const networks = {};
  for (const result of results) {
    const name = ObjC.unwrap(result.ssid);
    // the scale of CoreWiFi's signalStrength, which the lua side expects
    const strength = (Number(result.rssiValue) + 90) / 60;
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

  return JSON.stringify(
    Object.values(networks).sort((a, b) => b.strength - a.strength),
  );
}
