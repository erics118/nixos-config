import sys, signal, subprocess, threading, time
from datetime import datetime
import ScreenCaptureKit as SC
import CoreMedia as CM
import AVFoundation as AV
from Foundation import NSObject, NSURL, NSRunLoop, NSDate

out_path = sys.argv[1]
duration = float(sys.argv[2]) if len(sys.argv) > 2 else 0
done = threading.Event()
finished = threading.Event()
state = {}


class RecDelegate(NSObject):
    def recordingOutputDidStartRecording_(self, rec):
        print("recording started", datetime.now().strftime("%H:%M:%S.%f"), flush=True)

    def recordingOutput_didFailWithError_(self, rec, err):
        print("recording failed", err, flush=True)
        finished.set()
        done.set()

    def recordingOutputDidFinishRecording_(self, rec):
        print("recording finished", flush=True)
        finished.set()


def got_content(content, err):
    if err:
        print("content error", err)
        done.set()
        return
    display = content.displays()[0]
    filt = SC.SCContentFilter.alloc().initWithDisplay_excludingWindows_(display, [])
    cfg = SC.SCStreamConfiguration.alloc().init()
    cfg.setWidth_(display.width() * 2)
    cfg.setHeight_(display.height() * 2)
    cfg.setMinimumFrameInterval_(CM.CMTimeMake(1, 120))
    cfg.setQueueDepth_(8)
    cfg.setShowsCursor_(True)
    stream = SC.SCStream.alloc().initWithFilter_configuration_delegate_(filt, cfg, None)

    rcfg = SC.SCRecordingOutputConfiguration.alloc().init()
    rcfg.setOutputURL_(NSURL.fileURLWithPath_(out_path))
    rcfg.setOutputFileType_(AV.AVFileTypeQuickTimeMovie)
    rcfg.setVideoCodecType_(AV.AVVideoCodecTypeHEVC)
    delegate = RecDelegate.alloc().init()
    rec = SC.SCRecordingOutput.alloc().initWithConfiguration_delegate_(rcfg, delegate)
    ok, e = stream.addRecordingOutput_error_(rec, None)
    if not ok:
        print("addRecordingOutput error", e)
        done.set()
        return
    state.update(stream=stream, rec=rec, delegate=delegate)

    def started(e):
        if e:
            print("start error", e)
            done.set()
            return
        print(f"capturing {display.width()*2}x{display.height()*2} at up to 120 fps", flush=True)
        if duration:
            threading.Timer(duration, done.set).start()

    stream.startCaptureWithCompletionHandler_(started)


signal.signal(signal.SIGINT, lambda *_: done.set())
signal.signal(signal.SIGTERM, lambda *_: done.set())

# the red sketchybar apple warns the user 3s ahead and stays red while recording
subprocess.run(["sketchybar", "--set", "apple", "icon.highlight_color=0xfff38ba8", "icon.highlight=on"])
try:
    time.sleep(3)
    SC.SCShareableContent.getShareableContentWithCompletionHandler_(got_content)
    while not done.is_set():
        NSRunLoop.currentRunLoop().runUntilDate_(NSDate.dateWithTimeIntervalSinceNow_(0.1))

    if "stream" in state:
        state["stream"].stopCaptureWithCompletionHandler_(lambda e: None)
        for _ in range(100):
            if finished.is_set():
                break
            NSRunLoop.currentRunLoop().runUntilDate_(NSDate.dateWithTimeIntervalSinceNow_(0.1))
finally:
    subprocess.run(["sketchybar", "--set", "apple", "icon.highlight=off"])
