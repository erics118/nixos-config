#include <AppKit/AppKit.h>
#include <Carbon/Carbon.h>

void ax_init() {
  const void *keys[] = {kAXTrustedCheckOptionPrompt};
  const void *values[] = {kCFBooleanTrue};

  CFDictionaryRef options;
  options = CFDictionaryCreate(
      kCFAllocatorDefault, keys, values, sizeof(keys) / sizeof(*keys),
      &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

  bool trusted = AXIsProcessTrustedWithOptions(options);
  CFRelease(options);
  if (!trusted)
    exit(1);
}

void ax_perform_click(AXUIElementRef element) {
  if (!element)
    return;
  AXUIElementPerformAction(element, kAXCancelAction);
  usleep(150000);
  AXUIElementPerformAction(element, kAXPressAction);
}

CFStringRef ax_get_title(AXUIElementRef element) {
  CFTypeRef title = NULL;
  AXError error =
      AXUIElementCopyAttributeValue(element, kAXTitleAttribute, &title);

  if (error != kAXErrorSuccess)
    return NULL;
  return title;
}

void ax_select_menu_option(AXUIElementRef app, int id) {
  AXUIElementRef menubars_ref = NULL;
  CFArrayRef children_ref = NULL;

  AXError error = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute,
                                                (CFTypeRef *)&menubars_ref);
  if (error == kAXErrorSuccess) {
    error = AXUIElementCopyAttributeValue(
        menubars_ref, kAXVisibleChildrenAttribute, (CFTypeRef *)&children_ref);

    if (error == kAXErrorSuccess) {
      uint32_t count = CFArrayGetCount(children_ref);
      if (id < count) {
        AXUIElementRef item = CFArrayGetValueAtIndex(children_ref, id);
        ax_perform_click(item);
      }
      if (children_ref)
        CFRelease(children_ref);
    }
    if (menubars_ref)
      CFRelease(menubars_ref);
  }
}

CGRect ax_get_frame(AXUIElementRef element) {
  CFTypeRef position_ref = NULL;
  CFTypeRef size_ref = NULL;
  AXUIElementCopyAttributeValue(element, kAXPositionAttribute, &position_ref);
  AXUIElementCopyAttributeValue(element, kAXSizeAttribute, &size_ref);

  CGRect frame = CGRectZero;
  if (position_ref) {
    AXValueGetValue(position_ref, kAXValueCGPointType, &frame.origin);
    CFRelease(position_ref);
  }
  if (size_ref) {
    AXValueGetValue(size_ref, kAXValueCGSizeType, &frame.size);
    CFRelease(size_ref);
  }
  return frame;
}

// one line per menu: title, its native x and width in points, then the
// menu bar child index that -s takes, tab separated
void ax_print_menu_options(AXUIElementRef app) {
  AXUIElementRef menubars_ref = NULL;
  CFTypeRef menubar = NULL;
  CFArrayRef children_ref = NULL;

  AXError error = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute,
                                                (CFTypeRef *)&menubars_ref);
  if (error == kAXErrorSuccess) {
    error = AXUIElementCopyAttributeValue(
        menubars_ref, kAXVisibleChildrenAttribute, (CFTypeRef *)&children_ref);

    if (error == kAXErrorSuccess) {
      uint32_t count = CFArrayGetCount(children_ref);

      for (int i = 1; i < count; i++) {
        AXUIElementRef item = CFArrayGetValueAtIndex(children_ref, i);
        CFTypeRef title = ax_get_title(item);

        if (title) {
          CGRect frame = ax_get_frame(item);
          printf("%s\t%.0f\t%.0f\t%d\n",
                 [(__bridge NSString *)title UTF8String], frame.origin.x,
                 frame.size.width, i);
          CFRelease(title);
        }
      }
    }
    if (menubars_ref)
      CFRelease(menubars_ref);
    if (children_ref)
      CFRelease(children_ref);
  }
}

extern int SLSMainConnectionID();
extern void _SLPSGetFrontProcess(ProcessSerialNumber *psn);
extern void SLSGetConnectionIDForPSN(int cid, ProcessSerialNumber *psn,
                                     int *cid_out);
extern void SLSConnectionGetPID(int cid, pid_t *pid_out);
AXUIElementRef ax_get_front_app() {
  ProcessSerialNumber psn;
  _SLPSGetFrontProcess(&psn);
  int target_cid;
  SLSGetConnectionIDForPSN(SLSMainConnectionID(), &psn, &target_cid);

  pid_t pid;
  SLSConnectionGetPID(target_cid, &pid);
  return AXUIElementCreateApplication(pid);
}

// name is the localized name, which sketchybar sends as INFO with front_app_switched
// background processes can share it, like the Messages assistant extension
AXUIElementRef ax_get_app_named(const char *name) {
  NSString *target = [NSString stringWithUTF8String:name];
  for (NSRunningApplication *app in
       [[NSWorkspace sharedWorkspace] runningApplications]) {
    if (app.activationPolicy == NSApplicationActivationPolicyRegular &&
        [app.localizedName isEqualToString:target])
      return AXUIElementCreateApplication(app.processIdentifier);
  }
  return NULL;
}

int main(int argc, char **argv) {
  if (argc == 1) {
    printf("Usage: %s [-l [app] | -s id ]\n", argv[0]);
    exit(0);
  }
  ax_init();
  if (strcmp(argv[1], "-l") == 0) {
    // the named app can still be launching while the front process is the previous app
    AXUIElementRef app =
        argc == 3 ? ax_get_app_named(argv[2]) : ax_get_front_app();
    if (!app)
      return 1;
    ax_print_menu_options(app);
    CFRelease(app);
  } else if (argc == 3 && strcmp(argv[1], "-s") == 0) {
    int id = 0;
    if (sscanf(argv[2], "%d", &id) == 1) {
      AXUIElementRef app = ax_get_front_app();
      if (!app)
        return 1;
      ax_select_menu_option(app, id);
      CFRelease(app);
    }
  }
  return 0;
}
