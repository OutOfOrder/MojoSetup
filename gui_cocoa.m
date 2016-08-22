/**
 * MojoSetup; a portable, flexible installation application.
 *
 * Please see the file LICENSE.txt in the source's root directory.
 *
 *  This file written by Ryan C. Gordon.
 */

#if !SUPPORT_GUI_COCOA
#error Something is wrong in the build system.
#endif

#import <Cocoa/Cocoa.h>

#undef true
#undef false

#define BUILDING_EXTERNAL_PLUGIN 1
#include "gui.h"

#import "gui_cocoa/MojoSetupSplashView.h"
#import "gui_cocoa/MojoSetupController.h"

MOJOGUI_PLUGIN(cocoa)

#if !GUI_STATIC_LINK_COCOA
CREATE_MOJOGUI_ENTRY_POINT(cocoa)
#endif

static NSAutoreleasePool *GAutoreleasePool = nil;

// Override [NSApplication sendEvent], so we can catch custom events.
@interface MojoSetupApplication : NSApplication
{
}
- (void)sendEvent:(NSEvent *)event;
@end // interface MojoSetupApplication

@implementation MojoSetupApplication
    - (void)sendEvent:(NSEvent *)event
    {
        if ([event type] == NSApplicationDefined)
            [((MojoSetupController *)[self delegate]) doCustomEvent:event];
        [super sendEvent:event];
    } // sendEvent
@end // implementation MojoSetupApplication


static uint8 MojoGui_cocoa_priority(boolean istty)
{
    // obviously this is the thing you want on Mac OS X.
    return MOJOGUI_PRIORITY_TRY_FIRST;
} // MojoGui_cocoa_priority


static boolean MojoGui_cocoa_init(void)
{
    // This lets a stdio app become a GUI app. Otherwise, you won't get
    //  GUI events from the system and other things will fail to work.
    // Putting the app in an application bundle does the same thing.
    //  TransformProcessType() is a 10.3+ API. SetFrontProcess() is 10.0+.
    if (TransformProcessType != NULL)  // check it as a weak symbol.
    {
        ProcessSerialNumber psn = { 0, kCurrentProcess };
        TransformProcessType(&psn, kProcessTransformToForegroundApplication);
        SetFrontProcess(&psn);
    } // if

    GAutoreleasePool = [[NSAutoreleasePool alloc] init];

    // !!! FIXME: make sure we have access to the desktop...may be ssh'd in
    // !!! FIXME:  as another user that doesn't have the Finder loaded or
    // !!! FIXME:  something.

    // For NSApp to be our subclass, instead of default NSApplication.
    [MojoSetupApplication sharedApplication];
    if ([NSBundle loadNibNamed:@"MojoSetup" owner:NSApp] == NO)
        return false;

    // Force NSApp initialization stuff. MojoSetupController is set, in the
    //  .nib, to be NSApp's delegate. Its applicationDidFinishLaunching calls
    //  [NSApp stop] to break event loop right away so we can continue.
    [NSApp run];

    return true;  // always succeeds.
} // MojoGui_cocoa_init


static void MojoGui_cocoa_deinit(void)
{
    [GAutoreleasePool release];
    GAutoreleasePool = nil;
    // !!! FIXME: destroy nib and NSApp?
} // MojoGui_cocoa_deinit


static void MojoGui_cocoa_msgbox(const char *title, const char *text)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSApp delegate] fireCustomEvent:CUSTOMEVENT_MSGBOX data1:(NSInteger)title data2:(NSInteger)text atStart:YES];
    [pool release];
} // MojoGui_cocoa_msgbox


static boolean MojoGui_cocoa_promptyn(const char *title, const char *text,
                                      boolean defval)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSApp delegate] fireCustomEvent:CUSTOMEVENT_PROMPTYN data1:(NSInteger)title data2:(NSInteger)text atStart:YES];
    const MojoGuiYNAN ynan = [[NSApp delegate] getAnswerYNAN];
    [pool release];
    assert((ynan == MOJOGUI_YES) || (ynan == MOJOGUI_NO));
    return (ynan == MOJOGUI_YES);
} // MojoGui_cocoa_promptyn


static MojoGuiYNAN MojoGui_cocoa_promptynan(const char *title,
                                            const char *text,
                                            boolean defval)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSApp delegate] fireCustomEvent:CUSTOMEVENT_PROMPTYNAN data1:(NSInteger)title data2:(NSInteger)text atStart:YES];
    const MojoGuiYNAN retval = [[NSApp delegate] getAnswerYNAN];
    [pool release];
    return retval;
} // MojoGui_cocoa_promptynan


static boolean MojoGui_cocoa_start(const char *title,
                                   const char *package_name,
                                   const MojoGuiSplash *splash)
{
printf("start\n");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSApp delegate] prepareWidgets:entry withTitle:title andPackage:package_name andSplash:splash];
    [pool release];
    return true;
} // MojoGui_cocoa_start


static void MojoGui_cocoa_stop(void)
{
printf("stop\n");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSApp delegate] unprepareWidgets];
    [pool release];
} // MojoGui_cocoa_stop


static int MojoGui_cocoa_readme(const char *name, const uint8 *data,
                                    size_t len, boolean can_back,
                                    boolean can_fwd)
{
printf("readme\n");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *str = [[[NSString alloc] initWithBytes:data length:len encoding:NSUTF8StringEncoding] autorelease];
    const int retval = [[NSApp delegate] doReadme:name text:str canBack:can_back canFwd:can_fwd];
    [pool release];
    return retval;
} // MojoGui_cocoa_readme


static int MojoGui_cocoa_options(MojoGuiSetupOptions *opts,
                       boolean can_back, boolean can_fwd)
{
printf("options\n");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    const int retval = [[NSApp delegate] doOptions:opts canBack:can_back canFwd:can_fwd];
    [pool release];
    return retval;
} // MojoGui_cocoa_options


static char *MojoGui_cocoa_destination(const char **recommends, int recnum,
                                       int *command, boolean can_back,
                                       boolean can_fwd)
{
printf("destination\n");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    char *retval = [[NSApp delegate] doDestination:recommends recnum:recnum command:command canBack:can_back canFwd:can_fwd];
    [pool release];
    return retval;
} // MojoGui_cocoa_destination


static int MojoGui_cocoa_productkey(const char *desc, const char *fmt,
                                    char *buf, const int buflen,
                                    boolean can_back, boolean can_fwd)
{
printf("productkey\n");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    const int retval = [[NSApp delegate] doProductKey:desc fmt:fmt buf:buf buflen:buflen canBack:can_back canFwd:can_fwd];
    [pool release];
    return retval;
} // MojoGui_cocoa_productkey


static boolean MojoGui_cocoa_insertmedia(const char *medianame)
{
printf("insertmedia\n");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSApp delegate] fireCustomEvent:CUSTOMEVENT_INSERTMEDIA data1:(NSInteger)medianame data2:0 atStart:YES];
    const MojoGuiYNAN ynan = [[NSApp delegate] getAnswerYNAN];
    assert((ynan == MOJOGUI_YES) || (ynan == MOJOGUI_NO));
    [pool release];
    return (ynan == MOJOGUI_YES);
} // MojoGui_cocoa_insertmedia


static void MojoGui_cocoa_progressitem(void)
{
printf("progressitem\n");
    // no-op in this UI target.
} // MojoGui_cocoa_progressitem


static int MojoGui_cocoa_progress(const char *type, const char *component,
                                  int percent, const char *item,
                                  boolean can_cancel)
{
printf("progress\n");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    const int retval = [[NSApp delegate] doProgress:type component:component percent:percent item:item canCancel:can_cancel];
    [pool release];
    return retval;
} // MojoGui_cocoa_progress


static void MojoGui_cocoa_final(const char *msg)
{
printf("final\n");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSApp delegate] doFinal:msg];
    [pool release];
} // MojoGui_cocoa_final

// end of gui_cocoa.m ...

