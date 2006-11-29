
#include "universal.h"
#include "platform.h"
#include "fileio.h"
#include "gui.h"

static boolean initEverything(void)
{
    STUBBED("Init logging functionality.");

    // We have to panic on errors until the GUI is ready. Try to make things
    //  "succeed" unless they are catastrophic, and report problems later.

    // Start with the base archive work, since it might have GUI plugins.
    if (!MojoArchive_initBaseArchive())
        panic("Initial setup failed. Cannot continue.");

    else if (!MojoGui_initGuiPlugin())
        panic("Initial GUI setup failed. Cannot continue.");

    return true;
} // initEverything


static void deinitEverything(void)
{
    MojoGui_deinitGuiPlugin();
    STUBBED("Deinit logging functionality.");
} // deinitEverything


// This is called from main()/WinMain()/whatever.
int MojoSetup_main(int argc, char **argv)
{
    GArgc = argc;
    GArgv = argv;

    if (!initEverything())
        return 1;

    GGui->msgbox(GGui, "test", "testing");

    deinitEverything();
    return 0;
} // MojoSetup_main

// end of mojosetup.c ...
