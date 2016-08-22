/**
 * MojoSetup; a portable, flexible installation application.
 *
 * Please see the file LICENSE.txt in the source's root directory.
 *
 *  This file written by Ryan C. Gordon.
 */

@interface MojoSetupSplashView : NSView
{
    NSImage *splashImage;
}
- (void)setSplash: (const MojoGuiSplash *)splash;
@end
