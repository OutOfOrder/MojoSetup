/**
 * MojoSetup; a portable, flexible installation application.
 *
 * Please see the file LICENSE.txt in the source's root directory.
 *
 *  This file written by Ryan C. Gordon.
 */

#import "MojoSetupSplashView.h"

typedef enum
{
    CLICK_BACK=-1,
    CLICK_CANCEL,
    CLICK_NEXT,
    CLICK_NONE
} ClickValue;

// This nasty hack is because we appear to need to be under
//  -[NSApp run] when calling things like NSRunAlertPanel().
// So we push a custom event, call -[NSApp run], catch it, do
//  the panel, then call -[NSApp stop]. Yuck.
typedef enum
{
    CUSTOMEVENT_BASEVALUE=3234,
    CUSTOMEVENT_RUNQUEUE,
    CUSTOMEVENT_MSGBOX,
    CUSTOMEVENT_PROMPTYN,
    CUSTOMEVENT_PROMPTYNAN,
    CUSTOMEVENT_INSERTMEDIA,
} CustomEvent;

@interface MojoSetupController : NSObject
{
    IBOutlet NSButton *BackButton;
    IBOutlet NSButton *CancelButton;
    IBOutlet NSTextField *DestinationLabel;
    IBOutlet NSPathControl *DestinationPath;
    IBOutlet NSTextField *FinalText;
    IBOutlet NSWindow *MainWindow;
    IBOutlet NSButton *NextButton;
    IBOutlet NSProgressIndicator *ProgressBar;
    IBOutlet NSTextField *ProgressComponentLabel;
    IBOutlet NSTextField *ProgressItemLabel;
    IBOutlet NSTextView *ReadmeText;
    IBOutlet NSTabView *TabView;
    IBOutlet NSTextField *TitleLabel;
    IBOutlet NSMenuItem *QuitMenuItem;
    IBOutlet NSMenuItem *AboutMenuItem;
    IBOutlet NSMenuItem *HideMenuItem;
    IBOutlet NSMenuItem *WindowMenuItem;
    IBOutlet NSMenuItem *HideOthersMenuItem;
    IBOutlet NSMenuItem *ShowAllMenuItem;
    IBOutlet NSMenuItem *ServicesMenuItem;
    IBOutlet NSMenuItem *MinimizeMenuItem;
    IBOutlet NSMenuItem *ZoomMenuItem;
    IBOutlet NSMenuItem *BringAllToFrontMenuItem;
    IBOutlet MojoSetupSplashView *SplashView;
    IBOutlet NSView *InstallerContent;
    IBOutlet NSView *OptionsView;
    ClickValue clickValue;
    boolean canForward;
    boolean needToBreakEventLoop;
    boolean finalPage;
    MojoGuiYNAN answerYNAN;
    MojoGuiSetupOptions *mojoOpts;
    NSString *packageName;

    const MojoSetupEntryPoints *entry;
}
- (void)awakeFromNib;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (void)prepareWidgets:(const MojoSetupEntryPoints*)entry withTitle:(const char*)winTitle andPackage:(const char*)package_name andSplash:(const MojoGuiSplash*)splash;
- (void)unprepareWidgets;
- (void)fireCustomEvent:(CustomEvent)eventType data1:(NSInteger)data1 data2:(NSInteger)data2 atStart:(BOOL)atStart;
- (void)doCustomEvent:(NSEvent *)event;
- (void)doMsgBox:(const char *)title text:(const char *)text;
- (void)doPromptYN:(const char *)title text:(const char *)text;
- (void)doPromptYNAN:(const char *)title text:(const char *)text;
- (void)doInsertMedia:(const char *)medianame;
- (MojoGuiYNAN)getAnswerYNAN;
- (IBAction)backClicked:(NSButton *)sender;
- (IBAction)cancelClicked:(NSButton *)sender;
- (IBAction)nextClicked:(NSButton *)sender;
- (IBAction)pathChosen:(NSPathControl *)sender;
- (IBAction)menuQuit:(NSMenuItem *)sender;
- (int)doPage:(NSString *)pageId title:(const char *)_title canBack:(boolean)canBack canFwd:(boolean)canFwd canCancel:(boolean)canCancel canFwdAtStart:(boolean)canFwdAtStart shouldBlock:(BOOL)shouldBlock;
- (int)doReadme:(const char *)title text:(NSString *)text canBack:(boolean)canBack canFwd:(boolean)canFwd;
- (void)setOptionTreeSensitivity:(MojoGuiSetupOptions *)opts enabled:(boolean)val;
- (void)optionToggled:(id)toggle;
- (NSView *)createNewOptionLevel:(NSView *)box;
- (void)buildOptions:(MojoGuiSetupOptions *)opts view:(NSView *)box sensitive:(boolean)sensitive;
- (int)doOptions:(MojoGuiSetupOptions *)opts canBack:(boolean)canBack canFwd:(boolean)canFwd;
- (char *)doDestination:(const char **)recommends recnum:(int)recnum command:(int *)command canBack:(boolean)canBack canFwd:(boolean)canFwd;
- (int)doProductKey:(const char *)desc fmt:(const char *)fmt buf:(char *)buf buflen:(const int)buflen canBack:(boolean)canBack canFwd:(boolean)canFwd;
- (int)doProgress:(const char *)type component:(const char *)component percent:(int)percent item:(const char *)item canCancel:(boolean)canCancel;
- (void)doFinal:(const char *)msg;
@end // interface MojoSetupController
