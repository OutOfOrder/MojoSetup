#import <Cocoa/Cocoa.h>
#undef true
#undef false

#define BUILDING_EXTERNAL_PLUGIN 1
#include "gui.h"

#import "MojoSetupSplashView.h"

@implementation MojoSetupSplashView

- (void)setSplash:(const MojoGuiSplash *)splash
{
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:(unsigned char**)&splash->rgba
                                                                         pixelsWide:splash->w
                                                                         pixelsHigh:splash->h
                                                                      bitsPerSample:8
                                                                    samplesPerPixel:4
                                                                           hasAlpha:YES
                                                                           isPlanar:NO
                                                                     colorSpaceName:NSCalibratedRGBColorSpace
                                                                       bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                                                                        bytesPerRow:4 * splash->w
                                                                       bitsPerPixel:32];
    splashImage = [[NSImage alloc] initWithSize:NSMakeSize(splash->w, splash->h)];
    [splashImage addRepresentation:imageRep];
    [imageRep release];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect rect = [self bounds];
    NSSize size = [splashImage size];
    rect.origin.x = (rect.size.width - size.width) / 2;
    rect.size = size;

    [NSBezierPath strokeRect:[self bounds]];
    [splashImage drawInRect:rect];
}

- (void)dealloc
{
    [splashImage release];
    [super dealloc];
}

@end
