// since macOS 27.2 the connected network's name is hidden from osascript, which has no location access
// scan results still carry names, so the name is the cached result on our channel nearest our rssi
ObjC.import("CoreWLAN");

const wifi = $.CWWiFiClient.sharedWiFiClient.interface;
// jxa returns these integers as strings
const rssi = Number(wifi.rssiValue);
const channel = wifi.wlanChannel.isNil()
  ? null
  : wifi.wlanChannel.channelNumber;

let name = "";
let best = Infinity;
const cached = wifi.cachedScanResults;
const results = cached.isNil() ? [] : ObjC.unwrap(cached.allObjects);
for (const result of results) {
  const ssid = ObjC.unwrap(result.ssid);
  const distance = Math.abs(Number(result.rssiValue) - rssi);
  if (
    channel !== null &&
    ssid &&
    result.wlanChannel.channelNumber === channel &&
    distance < best
  ) {
    name = ssid;
    best = distance;
  }
}

JSON.stringify({
  power: wifi.powerOn,
  name: name,
  // rssi is 0 when not associated; the scale matches CoreWiFi's signalStrength
  strength: rssi === 0 ? 0 : (rssi + 90) / 60,
});
