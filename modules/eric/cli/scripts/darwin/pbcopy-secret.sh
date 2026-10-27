#!/usr/bin/env bash
# pbcopy, but marked concealed so clipboard managers skip it
# https://nspasteboard.org

set -euo pipefail

osascript -l JavaScript -e '
ObjC.import("AppKit")
const data = $.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile
const text = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)
const pb = $.NSPasteboard.generalPasteboard
pb.clearContents
pb.setStringForType(text, $.NSPasteboardTypeString)
pb.setStringForType("", "org.nspasteboard.ConcealedType")
undefined'
