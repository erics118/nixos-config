#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/hid/IOHIDUsageTables.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <IOKit/hidsystem/IOHIDServiceClient.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

// private, type 2 is a passive client that needs no input monitoring permission
IOHIDEventSystemClientRef
IOHIDEventSystemClientCreateWithType(CFAllocatorRef, uint32_t, CFDictionaryRef);

// HIDCapsLockLED is private
// On and Off force the light, Auto hands it back to caps lock
static int set_led(CFStringRef mode) {
  IOHIDEventSystemClientRef client =
      IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, 2, NULL);
  if (!client)
    return 0;
  CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
  int accepted = 0;
  for (CFIndex i = 0; services && i < CFArrayGetCount(services); i++) {
    IOHIDServiceClientRef service =
        (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
    if (IOHIDServiceClientConformsTo(service, kHIDPage_GenericDesktop,
                                     kHIDUsage_GD_Keyboard) &&
        IOHIDServiceClientSetProperty(service, CFSTR("HIDCapsLockLED"), mode))
      accepted++;
  }
  if (services)
    CFRelease(services);
  CFRelease(client);
  return accepted;
}

// nanoseconds since the last keyboard, mouse, or trackpad input, or -1
static int64_t idle_ns(void) {
  io_service_t hid = IOServiceGetMatchingService(
      kIOMainPortDefault, IOServiceMatching("IOHIDSystem"));
  CFTypeRef value = IORegistryEntryCreateCFProperty(hid, CFSTR("HIDIdleTime"),
                                                    kCFAllocatorDefault, 0);
  int64_t ns = -1;
  if (value && CFGetTypeID(value) == CFNumberGetTypeID())
    CFNumberGetValue(value, kCFNumberSInt64Type, &ns);
  if (value)
    CFRelease(value);
  IOObjectRelease(hid);
  return ns;
}

// light the led until the next input, from a detached child so the caller
// returns at once
static void light_until_input(void) {
  // detach before any CoreFoundation use, which is not fork safe
  if (fork() != 0)
    return;
  setsid();
  int null = open("/dev/null", O_RDWR);
  dup2(null, 0);
  dup2(null, 1);
  dup2(null, 2);
  if (!set_led(CFSTR("On")))
    _exit(1);
  // idle time drops back toward zero on any input
  int64_t last = idle_ns(), now;
  while ((now = idle_ns()) >= last && now >= 0) {
    last = now;
    usleep(250000);
  }
  set_led(CFSTR("Auto"));
  _exit(0);
}

// run a command, then light the led until input, exiting with the command's
// status
static int run_then_light(char **cmd) {
  pid_t pid = fork();
  if (pid == 0) {
    execvp(cmd[0], cmd);
    perror(cmd[0]);
    _exit(127);
  }
  int status;
  if (pid < 0 || waitpid(pid, &status, 0) < 0) {
    perror("capsled");
    return 1;
  }
  light_until_input();
  return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}

int main(int argc, char **argv) {
  if (argc >= 3 && !strcmp(argv[1], "wait"))
    return run_then_light(argv + 2);

  CFStringRef mode = NULL;
  if (argc >= 2 && !strcmp(argv[1], "on"))
    mode = CFSTR("On");
  if (argc >= 2 && !strcmp(argv[1], "off"))
    mode = CFSTR("Off");
  if (argc >= 2 && !strcmp(argv[1], "auto"))
    mode = CFSTR("Auto");
  int until_input =
      argc == 3 && mode == CFSTR("On") && !strcmp(argv[2], "--until-input");
  if (!mode || (argc == 3 && !until_input) || argc > 3) {
    fprintf(stderr, "usage: capsled on [--until-input] | off | auto | wait "
                    "<command> [args...]\n");
    return 2;
  }

  if (until_input) {
    light_until_input();
    return 0;
  }
  if (!set_led(mode)) {
    fprintf(stderr, "capsled: no keyboard accepted the change\n");
    return 1;
  }
  return 0;
}
