#import <Cocoa/Cocoa.h>
#undef true
#undef false

#define BUILDING_EXTERNAL_PLUGIN 1
#include "gui.h"
#include "platform.h"

#import "MojoSetupController.h"


@implementation MojoSetupController
- (void)awakeFromNib
{
    clickValue = CLICK_NONE;
    canForward = false;
    answerYNAN = MOJOGUI_NO;
    needToBreakEventLoop = false;
    finalPage = false;
    mojoOpts = nil;
} // awakeFromNib

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    printf("didfinishlaunching\n");
    [NSApp stop:self];  // break out of NSApp::run()
} // applicationDidFinishLaunching

- (void)prepareWidgets:(const MojoSetupEntryPoints*)_entry withTitle:(const char*)winTitle andPackage:(const char*)package_name andSplash:(const MojoGuiSplash*)splash
{
    entry = _entry;
    if (package_name)
    {
        packageName = [[NSString alloc] initWithUTF8String:package_name];
    }
    if (false && splash->rgba)
    {
        NSRect frame = MainWindow.frame;
        NSRect screen = MainWindow.screen.visibleFrame;

        frame.size.height = InstallerContent.frame.size.height + splash->h;
        frame.origin.y = (screen.size.height - frame.size.height) / 2;

        [MainWindow setFrame: frame display:YES];

        frame = [SplashView frame];
        frame.size.height = splash->h;
        SplashView.frame = frame;
        [SplashView setSplash:splash];
    } else {
        NSRect frame = MainWindow.frame;
        NSRect screen = MainWindow.screen.visibleFrame;

        frame.size.height = InstallerContent.frame.size.height;
        frame.origin.y = (screen.size.height - frame.size.height) / 2;

        [SplashView setHidden:YES];
        frame.origin = NSZeroPoint;
        [MainWindow setFrame: frame display:YES];
        InstallerContent.frame = frame;
    }
    [DestinationLabel setStringValue:[NSString stringWithUTF8String:_("Folder:")]];
#if 1
    [BackButton setTitle:[NSString stringWithUTF8String:_("Back")]];
    [NextButton setTitle:[NSString stringWithUTF8String:_("Next")]];
    [CancelButton setTitle:[NSString stringWithUTF8String:_("Cancel")]];

#else
    // !!! FIXME: there's probably a better way to do this.
    // Set the correct localization for the buttons, then resize them so
    //  the new text fits perfectly. After that, we need to reposition
    //  them so they don't look scattered.
    NSRect frameBack = [BackButton frame];
    NSRect frameNext = [NextButton frame];
    NSRect frameCancel = [CancelButton frame];
    const float startX = frameCancel.origin.x + frameCancel.size.width;
    const float spacing = (frameBack.origin.x + frameBack.size.width) - frameNext.origin.x;
    [BackButton setTitle:[NSString stringWithUTF8String:_("Back")]];
    [NextButton setTitle:[NSString stringWithUTF8String:_("Next")]];
    [CancelButton setTitle:[NSString stringWithUTF8String:_("Cancel")]];
    [BackButton sizeToFit];
    [NextButton sizeToFit];
    [CancelButton sizeToFit];
    frameBack = [BackButton frame];
    frameNext = [NextButton frame];
    frameCancel = [CancelButton frame];
    frameCancel.origin.x = startX - frameCancel.size.width;
    frameNext.origin.x = (frameCancel.origin.x - frameNext.size.width) - spacing;
    frameBack.origin.x = (frameNext.origin.x - frameBack.size.width) - spacing;
    [CancelButton setFrame:frameCancel];
    [CancelButton setNeedsDisplay:YES];
    [NextButton setFrame:frameNext];
    [NextButton setNeedsDisplay:YES];
    [BackButton setFrame:frameBack];
    [BackButton setNeedsDisplay:YES];
#endif

    [ProgressBar setUsesThreadedAnimation:YES];  // we don't pump fast enough.
    [ProgressBar startAnimation:self];

    [WindowMenuItem setTitle:[NSString stringWithUTF8String:_("Window")]];
    [HideOthersMenuItem setTitle:[NSString stringWithUTF8String:_("Hide Others")]];
    [ShowAllMenuItem setTitle:[NSString stringWithUTF8String:_("Show All")]];
    [ServicesMenuItem setTitle:[NSString stringWithUTF8String:_("Services")]];
    [MinimizeMenuItem setTitle:[NSString stringWithUTF8String:_("Minimize")]];
    [ZoomMenuItem setTitle:[NSString stringWithUTF8String:_("Zoom")]];
    [BringAllToFrontMenuItem setTitle:[NSString stringWithUTF8String:_("Bring All to Front")]];

    NSString *appName;
    appName = (NSString *) [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    if (appName == nil)
        appName = [[NSProcessInfo processInfo] processName];

    const char *utf8AppName = [appName UTF8String];
    char *text;

    text = format(_("About %0"), utf8AppName);
    [AboutMenuItem setTitle:[NSString stringWithUTF8String:text]];
    free(text);

    text = format(_("Hide %0"), utf8AppName);
    [HideMenuItem setTitle:[NSString stringWithUTF8String:text]];
    free(text);

    text = format(_("Quit %0"), utf8AppName);
    [QuitMenuItem setTitle:[NSString stringWithUTF8String:text]];
    free(text);

    [MainWindow setTitle:[NSString stringWithUTF8String:winTitle]];
    [MainWindow center];
    [MainWindow makeKeyAndOrderFront:self];
} // prepareWidgets

- (void)unprepareWidgets
{
    [packageName release];
    [MainWindow orderOut:self];
    entry = NULL;
} // unprepareWidgets

- (void)fireCustomEvent:(CustomEvent)eventType data1:(NSInteger)data1 data2:(NSInteger)data2 atStart:(BOOL)atStart
{
    NSEvent *event = [NSEvent otherEventWithType:NSApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:(short)eventType data1:data1 data2:data2];
    [NSApp postEvent:event atStart:atStart];
    [NSApp run];  // event handler _must_ call -[NSApp stop], or you block here forever.
} // fireCustomEvent

- (void)doCustomEvent:(NSEvent*)event
{
    printf("custom event!\n");
    switch ((CustomEvent) [event subtype])
    {
        case CUSTOMEVENT_RUNQUEUE:
            if ([NSApp modalWindow] != nil)
            {
                // If we're in a modal thing, so don't break the event loop.
                //  Just make a note to break it later.
                needToBreakEventLoop = true;
                return;
            } // if
            break;  // we just need the -[NSApp stop] call.
        case CUSTOMEVENT_MSGBOX:
            [self doMsgBox:(const char *)[event data1] text:(const char *)[event data2]];
            break;
        case CUSTOMEVENT_PROMPTYN:
            [self doPromptYN:(const char *)[event data1] text:(const char *)[event data2]];
            break;
        case CUSTOMEVENT_PROMPTYNAN:
            [self doPromptYNAN:(const char *)[event data1] text:(const char *)[event data2]];
            break;
        case CUSTOMEVENT_INSERTMEDIA:
            [self doInsertMedia:(const char *)[event data1]];
            break;
        default:
            return;  // let it go without breaking the event loop.
    } // switch

    [NSApp stop:self];  // break the event loop.
} // doCustomEvent

- (void)doMsgBox:(const char *)title text:(const char *)text
{
    NSString *titlestr = [NSString stringWithUTF8String:title];
    NSString *textstr = [NSString stringWithUTF8String:text];
    NSString *okstr = [NSString stringWithUTF8String:_("OK")];
    NSRunInformationalAlertPanel(titlestr, textstr, okstr, nil, nil);
    if (needToBreakEventLoop)
    {
        needToBreakEventLoop = false;
        [self fireCustomEvent:CUSTOMEVENT_RUNQUEUE data1:0 data2:0 atStart:NO];
    } // if
} // doMsgBox

- (void)doPromptYN:(const char *)title text:(const char *)text
{
    NSString *titlestr = [NSString stringWithUTF8String:title];
    NSString *textstr = [NSString stringWithUTF8String:text];
    NSString *yesstr = [NSString stringWithUTF8String:_("Yes")];
    NSString *nostr = [NSString stringWithUTF8String:_("No")];
    const NSInteger rc = NSRunAlertPanel(titlestr, textstr, yesstr, nostr, nil);
    answerYNAN = ((rc == NSAlertDefaultReturn) ? MOJOGUI_YES : MOJOGUI_NO);
    if (needToBreakEventLoop)
    {
        needToBreakEventLoop = false;
        [self fireCustomEvent:CUSTOMEVENT_RUNQUEUE data1:0 data2:0 atStart:NO];
    } // if
} // doPromptYN

- (void)doPromptYNAN:(const char *)title text:(const char *)text
{
    // !!! FIXME
    [self doPromptYN:title text:text];
} // doPromptYN

- (void)doInsertMedia:(const char *)medianame
{
    NSString *title = [NSString stringWithUTF8String:_("Media change")];
    char *fmt = xstrdup(_("Please insert '%0'"));
    char *_text = format(fmt, medianame);
    NSString *text = [NSString stringWithUTF8String:_text];
    free(_text);
    free(fmt);
    NSString *okstr = [NSString stringWithUTF8String:_("OK")];
    NSString *cancelstr = [NSString stringWithUTF8String:_("Cancel")];
    const NSInteger rc = NSRunAlertPanel(title, text, okstr, cancelstr, nil);
    answerYNAN = ((rc == NSAlertDefaultReturn) ? MOJOGUI_YES : MOJOGUI_NO);
    if (needToBreakEventLoop)
    {
        needToBreakEventLoop = false;
        [self fireCustomEvent:CUSTOMEVENT_RUNQUEUE data1:0 data2:0 atStart:NO];
    } // if
} // doInsertMedia

- (MojoGuiYNAN)getAnswerYNAN
{
    return answerYNAN;
} // getAnswerYNAN

- (IBAction)backClicked:(NSButton *)sender
{
    clickValue = CLICK_BACK;
    [NSApp stop:self];
} // backClicked

- (IBAction)cancelClicked:(NSButton *)sender
{
    char *title = xstrdup(_("Cancel installation"));
    char *text = xstrdup(_("Are you sure you want to cancel installation?"));
    [self doPromptYN:title text:text];
    free(title);
    free(text);
    if (answerYNAN == MOJOGUI_YES)
    {
        clickValue = CLICK_CANCEL;
        [NSApp stop:self];
    } // if
} // cancelClicked

- (IBAction)nextClicked:(NSButton *)sender
{
    clickValue = CLICK_NEXT;
    [NSApp stop:self];
} // nextClicked

- (IBAction)pathChosen:(NSPathControl *)sender {
    NSURL *url = [[sender clickedPathComponentCell] URL];
    if (url)
    {
        if (packageName)
        {
            url = [url URLByAppendingPathComponent:packageName];
        }
        [DestinationPath setURL:url];
    }
} // pathChosen

- (IBAction)menuQuit:(NSMenuItem *)sender
{
    if (finalPage)  // make this work like you clicked "finished".
        [self nextClicked:nil];
    else if ([CancelButton isEnabled])  // make this work like you clicked "cancel".
        [self cancelClicked:nil];
} // menuQuit

- (int)doPage:(NSString *)pageId title:(const char *)_title canBack:(boolean)canBack canFwd:(boolean)canFwd canCancel:(boolean)canCancel canFwdAtStart:(boolean)canFwdAtStart shouldBlock:(BOOL)shouldBlock
{
    [TitleLabel setStringValue:[NSString stringWithUTF8String:_title]];
    clickValue = CLICK_NONE;
    canForward = canFwd;
    [BackButton setEnabled:canBack ? YES : NO];
    [NextButton setEnabled:canFwdAtStart ? YES : NO];
    [CancelButton setEnabled:canCancel ? YES : NO];
    [TabView selectTabViewItemWithIdentifier:pageId];
    if (shouldBlock == NO)
        [self fireCustomEvent:CUSTOMEVENT_RUNQUEUE data1:0 data2:0 atStart:NO];
    else
    {
        [NSApp run];
        assert(clickValue < CLICK_NONE);
    } // else
    return (int) clickValue;
} // doPage

- (int)doReadme:(const char *)title text:(NSString *)text canBack:(boolean)canBack canFwd:(boolean)canFwd
{
    NSRange range = {0, 1};  // reset scrolling to start of text.
    [ReadmeText setString:text];
    [ReadmeText scrollRangeToVisible:range];
    return [self doPage:@"Readme" title:title canBack:canBack canFwd:canFwd canCancel:true canFwdAtStart:canFwd shouldBlock:YES];
} // doReadme

- (void)setOptionTreeSensitivity:(MojoGuiSetupOptions *)opts enabled:(boolean)val
{
    if (opts != nil)
    {
        [((id) opts->guiopaque) setEnabled:(val ? YES : NO)];
        [self setOptionTreeSensitivity:opts->next_sibling enabled:val];
        [self setOptionTreeSensitivity:opts->child enabled:(val && opts->value)];
    } // if
} // setOptionTreeSensitivity

- (MojoGuiSetupOptions *)findMojoOption:(id)obj opt:(MojoGuiSetupOptions *)opt
{
    // !!! FIXME: this is not ideal. How can we attach this pointer to
    // !!! FIXME:  the objects themselves so we don't have to walk a tree
    // !!! FIXME:  to find it on each action? The objects are controls
    // !!! FIXME:  and cells (distinct classes), and I don't control the
    // !!! FIXME:  creation of all of them (radio buttons).
    // !!! FIXME: Alternately, let's just hold a hashtable to map
    // !!! FIXME:  objects to options without walking this tree.
    if (opt == nil)
        return nil;

    MojoGuiSetupOptions *i;
    for (i = opt; i != nil; i = i->next_sibling)
    {
        if (i->guiopaque == ((void *) obj))
            return i;
        MojoGuiSetupOptions *rc = [self findMojoOption:obj opt:i->child];
        if (rc != nil)
            return rc;
    } // for

    return [self findMojoOption:obj opt:opt->child];
} // findMojoOption

- (void)optionToggled:(id)toggle
{
    MojoGuiSetupOptions *opts = [self findMojoOption:toggle opt:mojoOpts];
    assert(opts != nil);
    // !!! FIXME: cast is wrong. use a selector?
    const boolean enabled = ([((NSControl*)toggle) isEnabled] == YES);
    opts->value = enabled;
    [self setOptionTreeSensitivity:opts->child enabled:enabled];
} // optionToggled

- (NSView *)createNewOptionLevel:(NSView *)box
{
    NSRect frame = NSMakeRect(10, 10, 10, 10);
    NSView *widget = [[NSView alloc] initWithFrame:frame];
    [box addSubview:widget positioned:NSWindowBelow relativeTo:nil];
    [widget release];  // (box) owns it now.
    return widget;
} // newOptionLevel

// !!! FIXME: most of this mess is cut, pasted, and Cocoaized from the
// !!! FIXME:  GTK+ GUI. Can we abstract this in the high level and just
// !!! FIXME:  implement the target-specific bits in the plugins?
- (void)buildOptions:(MojoGuiSetupOptions *)opts view:(NSView *)box sensitive:(boolean)sensitive
{
    NSRect frame = NSMakeRect(10, 10, 10, 10);
    if (opts != nil)
    {
        if (opts->is_group_parent)
        {
            MojoGuiSetupOptions *kids = opts->child;
            NSView *childbox = nil;
            //GtkWidget *alignment = gtk_alignment_new(0.0, 0.5, 0, 0);
            //gtk_widget_show(alignment);

            // !!! FIXME: disable line wrap?
            // !!! FIXME: resize on superview resize?
            NSTextField *widget = [[NSTextField alloc] initWithFrame:frame];
            [widget setStringValue:[NSString stringWithUTF8String:opts->description]];
            [widget setEnabled:(sensitive ? YES : NO)];
            [widget setEditable:NO];
            [widget setSelectable:NO];
            [widget setBordered:NO];
            [widget setBezeled:NO];
            [widget setAlignment:NSLeftTextAlignment];
            [widget sizeToFit];
            if (opts->tooltip != nil)
                [widget setToolTip:[NSString stringWithUTF8String:opts->tooltip]];
            [box addSubview:widget positioned:NSWindowBelow relativeTo:nil];
            [widget release];  // (box) owns it now.
            //!!! FIXME[box sizeToFit];

            childbox = [self createNewOptionLevel:box];
            NSButtonCell *prototype = [[NSButtonCell alloc] init];
            [prototype setButtonType:NSRadioButton];
            [prototype setAllowsMixedState:NO];
            NSMatrix *matrix = [[NSMatrix alloc] initWithFrame:frame mode:NSRadioModeMatrix prototype:(NSCell *)prototype numberOfRows:0 numberOfColumns:1];
            [prototype release];
            int row = 0;
            while (kids)
            {
                [matrix addRow];
                NSButtonCell *cell = (NSButtonCell *) [matrix cellAtRow:row column:0];
                kids->guiopaque = cell;
                [cell setTitle:[NSString stringWithUTF8String:kids->description]];
                [matrix setState:(kids->value ? NSOnState : NSOffState) atRow:row column:0];
                [cell setEnabled:(kids->value ? YES : NO)];
                [cell setTarget:self];
                [cell setAction:@selector(optionToggled:)];

                if (kids->tooltip != nil)
                    [matrix setToolTip:[NSString stringWithUTF8String:kids->tooltip] forCell:cell];

                if (kids->child != nil)
                    [self buildOptions:kids->child view:[self createNewOptionLevel:childbox] sensitive:sensitive];

                kids = kids->next_sibling;
                row++;
            } // while

            [matrix sizeToCells];
            [childbox addSubview:matrix positioned:NSWindowBelow relativeTo:nil];
            [matrix release];  // childbox owns it now.
            //!!! FIXME: [childbox sizeToFit];
            //!!! FIXME: [[childbox superview] sizeToFit];
        } // if

        else
        {
            NSButton *widget = [[NSButton alloc] initWithFrame:frame];
            opts->guiopaque = widget;
            [widget setAllowsMixedState:NO];
            [widget setTitle:[NSString stringWithUTF8String:opts->description]];
            [widget setState:(opts->value ? NSOnState : NSOffState)];
            [widget setEnabled:(sensitive ? YES : NO)];
            [widget setTarget:self];
            [widget setAction:@selector(optionToggled:)];
            [box addSubview:widget positioned:NSWindowBelow relativeTo:nil];
            [widget release];  // (box) owns it now.
            //!!!FIXME:[box sizeToFit];

            if (opts->tooltip != nil)
                [widget setToolTip:[NSString stringWithUTF8String:opts->tooltip]];

            if (opts->child != nil)
                [self buildOptions:opts->child view:[self createNewOptionLevel:box] sensitive:((sensitive) && (opts->value))];
        } // else

        [self buildOptions:opts->next_sibling view:box sensitive:sensitive];
    } // if

    //!!! FIXME:[box sizeToFit];
} // buildOptions

- (int)doOptions:(MojoGuiSetupOptions *)opts canBack:(boolean)canBack canFwd:(boolean)canFwd
{
    // add all the option widgets to the page's view.
    [self buildOptions:opts view:OptionsView sensitive:true];

    // run the page.
    mojoOpts = opts;
    int retval = [self doPage:@"Options" title:_("Options") canBack:canBack canFwd:canFwd canCancel:true canFwdAtStart:canFwd shouldBlock:YES];
    mojoOpts = nil;

    // we're done, so nuke everything from the view.
    NSArray *array = [[OptionsView subviews] copy];
    NSEnumerator *enumerator = [array objectEnumerator];
    NSView *obj;
    while ((obj = (NSView *) [enumerator nextObject]) != nil)
        [obj removeFromSuperviewWithoutNeedingDisplay];
    [OptionsView setNeedsDisplay:YES];
    [array release];

    return retval;
} // doOptions

- (char *)doDestination:(const char **)recommends recnum:(int)recnum command:(int *)command canBack:(boolean)canBack canFwd:(boolean)canFwd
{
    const boolean fwdAtStart = ( (recnum > 0) && (*(recommends[0])) );
    NSString *defaultPath;
    if (recnum > 0)
        defaultPath = [NSString stringWithUTF8String:recommends[0]];
    else
        defaultPath = [NSString stringWithUTF8String:MojoPlatform_homedir()];

    [DestinationPath setURL:[NSURL fileURLWithPath:defaultPath isDirectory:YES]];

    *command = [self doPage:@"Destination" title:_("Destination") canBack:canBack canFwd:canFwd canCancel:true canFwdAtStart:fwdAtStart shouldBlock:YES];
    NSURL *url = [DestinationPath URL];
    char *retval = xstrdup([[url path] UTF8String]);
    return retval;
} // doDestination

- (int)doProductKey:(const char *)desc fmt:(const char *)fmt buf:(char *)buf buflen:(const int)buflen canBack:(boolean)canBack canFwd:(boolean)canFwd
{
    // !!! FIXME: write me!
    return [self doPage:@"ProductKey" title:desc canBack:canBack canFwd:canFwd canCancel:true canFwdAtStart:canFwd shouldBlock:YES];
} // doProductKey

- (int)doProgress:(const char *)type component:(const char *)component percent:(int)percent item:(const char *)item canCancel:(boolean)canCancel
{
    const BOOL indeterminate = (percent < 0) ? YES : NO;
    [ProgressComponentLabel setStringValue:[NSString stringWithUTF8String:component]];
    [ProgressItemLabel setStringValue:[NSString stringWithUTF8String:item]];
    [ProgressBar setIndeterminate:indeterminate];
    if (!indeterminate)
        [ProgressBar setDoubleValue:(double)percent];
    return [self doPage:@"Progress" title:type canBack:false canFwd:false canCancel:canCancel canFwdAtStart:false shouldBlock:NO];
} // doProgress

- (void)doFinal:(const char *)msg
{
    finalPage = true;
    [FinalText setStringValue:[NSString stringWithUTF8String:msg]];
    [NextButton setTitle:[NSString stringWithUTF8String:_("Finish")]];
    [self doPage:@"Final" title:_("Finish") canBack:false canFwd:true canCancel:false canFwdAtStart:true shouldBlock:YES];
} // doFinal
@end // implementation MojoSetupController
