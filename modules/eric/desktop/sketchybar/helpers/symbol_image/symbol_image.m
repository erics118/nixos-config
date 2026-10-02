#import <AppKit/AppKit.h>

@interface NSImage (Private)
+ (NSImage *)imageWithPrivateSystemSymbolName:(NSString *)name;
@end

// nil means apple's multicolor rendering
static NSColor *g_color;

// palette gives each layer its own color, otherwise layers are shades of g_color
static NSImage *load_symbol(NSString *name, CGFloat size, double value, NSArray<NSColor *> *palette) {
  NSImage *symbol = isnan(value)
                        ? [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil]
                        : [NSImage imageWithSystemSymbolName:name variableValue:value accessibilityDescription:nil];
  symbol = symbol ?: [NSImage imageWithPrivateSystemSymbolName:name];
  if (!symbol) {
    fprintf(stderr, "unknown symbol: %s\n", name.UTF8String);
    exit(1);
  }

  NSImageSymbolConfiguration *colors =
      palette  ? [NSImageSymbolConfiguration configurationWithPaletteColors:palette]
      : g_color ? [NSImageSymbolConfiguration configurationWithHierarchicalColor:g_color]
                : [NSImageSymbolConfiguration configurationPreferringMulticolor];
  NSImageSymbolConfiguration *config =
      [[NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightRegular]
          configurationByApplyingConfiguration:colors];
  return [symbol imageWithSymbolConfiguration:config];
}

// the charging symbol whose first layer, a bolt or a plug, goes on top of the battery
static NSString *battery_glyph(NSString *name) {
  if ([name isEqualToString:@"battery.bolt"]) return @"battery.100percent.bolt";
  if ([name isEqualToString:@"battery.plug"]) return @"battery.powerplug";
  return nil;
}

static NSSize battery_canvas(CGFloat size, NSString *glyph) {
  NSSize body = load_symbol(@"battery.100percent", size, NAN, nil).size;
  NSSize over = glyph ? load_symbol(glyph, size, NAN, nil).size : body;
  return NSMakeSize(MAX(body.width, over.width), MAX(body.height, over.height));
}

static void draw_battery(CGFloat size, double level, NSString *glyph, NSSize pt) {
  // battery.100percent layers are the fill, then the outline
  // under a glyph they are dimmed to 0.3 and 0.5 like apple's charging symbols
  NSColor *clear = NSColor.clearColor;
  NSColor *fill_color = [g_color colorWithAlphaComponent:glyph ? 0.3 : 1];
  NSColor *outline_color = [g_color colorWithAlphaComponent:glyph ? 0.5 : 1];
  NSImage *outline = load_symbol(@"battery.100percent", size, NAN, @[ clear, outline_color ]);
  NSImage *fill = load_symbol(@"battery.100percent", size, NAN, @[ fill_color, clear ]);
  NSRect rect = NSMakeRect(0, (pt.height - outline.size.height) / 2, outline.size.width, outline.size.height);
  [outline drawInRect:rect];

  // fill box of battery.100percent, measured by diffing it against battery.0percent
  CGFloat x0 = rect.size.width * 8 / 52, x1 = rect.size.width * 39 / 52;
  [NSGraphicsContext saveGraphicsState];
  NSRectClip(NSMakeRect(0, 0, x0 + (x1 - x0) * level, pt.height));
  [fill drawInRect:rect];
  [NSGraphicsContext restoreGraphicsState];

  if (!glyph) return;
  NSImage *top = load_symbol(glyph, size, NAN, @[ g_color, clear, clear ]);
  NSRect g = NSMakeRect(0, (pt.height - top.size.height) / 2, top.size.width, top.size.height);

  // cut a gap around the glyph so it reads over both the fill and the outline
  CGFloat gap = size / 15;
  for (int dx = -1; dx <= 1; dx++) {
    for (int dy = -1; dy <= 1; dy++) {
      [top drawInRect:NSOffsetRect(g, dx * gap, dy * gap)
             fromRect:NSZeroRect
            operation:NSCompositingOperationDestinationOut
             fraction:1];
    }
  }
  [top drawInRect:g];
}

int main(int argc, char **argv) {
  @autoreleasepool {
    if (argc != 5 && argc != 6) {
      fprintf(stderr,
              "usage: %s <symbol> <0xAARRGGBB | multicolor[:0xAARRGGBB]> <point size> <out.png> [value]\n"
              "  multicolor:0xAARRGGBB recolors the white parts of the multicolor symbol\n"
              "  value is the variable value (0-1) of the symbol\n"
              "  symbol battery, battery.bolt or battery.plug draws a battery filled to value\n",
              argv[0]);
      return 1;
    }
    NSString *name = @(argv[1]);
    uint32_t argb = (uint32_t)strtoul(argv[2], NULL, 16);
    CGFloat size = atof(argv[3]);
    double value = argc == 6 ? atof(argv[5]) : NAN;

    bool multicolor = strncmp(argv[2], "multicolor", 10) == 0;
    bool recolor_white = multicolor && argv[2][10] == ':';
    if (recolor_white) argb = (uint32_t)strtoul(argv[2] + 11, NULL, 16);

    if (!multicolor) {
      g_color = [NSColor colorWithSRGBRed:((argb >> 16) & 0xff) / 255.0
                                    green:((argb >> 8) & 0xff) / 255.0
                                     blue:(argb & 0xff) / 255.0
                                    alpha:((argb >> 24) & 0xff) / 255.0];
    }

    NSString *glyph = battery_glyph(name);
    BOOL battery = glyph || [name isEqualToString:@"battery"];
    NSSize pt = battery ? battery_canvas(size, glyph) : load_symbol(name, size, value, nil).size;

    // render at 2x for retina, sketchybar shows it 1:1 with image.scale 0.5
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                    pixelsWide:pt.width * 2
                                                                    pixelsHigh:pt.height * 2
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSCalibratedRGBColorSpace
                                                                   bytesPerRow:0
                                                                  bitsPerPixel:0];
    // colors are sRGB, a generic rgb tag makes macos shift them when sketchybar draws the png
    rep = [rep bitmapImageRepByRetaggingWithColorSpace:NSColorSpace.sRGBColorSpace];
    rep.size = pt;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    if (battery) {
      draw_battery(size, isnan(value) ? 1 : value, glyph, pt);
    } else {
      [load_symbol(name, size, value, nil) drawInRect:NSMakeRect(0, 0, pt.width, pt.height)];
    }
    [NSGraphicsContext restoreGraphicsState];

    if (recolor_white) {
      // pixels are premultiplied, so a white pixel has r, g and b equal to its alpha
      unsigned char *pixels = rep.bitmapData;
      for (NSInteger y = 0; y < rep.pixelsHigh; y++) {
        for (NSInteger x = 0; x < rep.pixelsWide; x++) {
          unsigned char *p = pixels + y * rep.bytesPerRow + x * 4;
          int a = p[3];
          if (a == 0 || p[0] < a * 0.9 || p[1] < a * 0.9 || p[2] < a * 0.9) continue;

          double alpha = a * (((argb >> 24) & 0xff) / 255.0);
          p[0] = ((argb >> 16) & 0xff) * alpha / 255;
          p[1] = ((argb >> 8) & 0xff) * alpha / 255;
          p[2] = (argb & 0xff) * alpha / 255;
          p[3] = alpha;
        }
      }
    }

    // trim transparent columns so the png width is the drawn width
    NSInteger x0 = rep.pixelsWide, x1 = -1;
    for (NSInteger y = 0; y < rep.pixelsHigh; y++) {
      for (NSInteger x = 0; x < rep.pixelsWide; x++) {
        if (rep.bitmapData[y * rep.bytesPerRow + x * 4 + 3] == 0) continue;
        x0 = MIN(x0, x);
        x1 = MAX(x1, x);
      }
    }
    if (x1 >= x0) {
      CGImageRef trimmed = CGImageCreateWithImageInRect(rep.CGImage, CGRectMake(x0, 0, x1 - x0 + 1, rep.pixelsHigh));
      rep = [[NSBitmapImageRep alloc] initWithCGImage:trimmed];
      CGImageRelease(trimmed);
    }

    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:@(argv[4]) atomically:YES] ? 0 : 1;
  }
}
