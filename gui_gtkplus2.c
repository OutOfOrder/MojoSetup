/**
 * MojoSetup; a portable, flexible installation application.
 *
 * Please see the file LICENSE.txt in the source's root directory.
 *
 *  This file written by Ryan C. Gordon.
 */

// Not only does GTK+ 2.x _look_ better than 1.x, it offers a lot of basic
//  functionality, like message boxes, that you'd expect to exist in a GUI
//  toolkit. In GTK+v1, you'd have to roll all that on your own!
//
// It's easier to implement in that regard, and produces a smaller DLL, but
//  it has a million dependencies, so you might need to use a GTK+v1 plugin,
//  too, in case they break backwards compatibility.

#if !SUPPORT_GUI_GTKPLUS2
#error Something is wrong in the build system.
#endif

#define BUILDING_EXTERNAL_PLUGIN 1
#include "gui.h"

MOJOGUI_PLUGIN(gtkplus2)

#if !GUI_STATIC_LINK_GTKPLUS2
CREATE_MOJOGUI_ENTRY_POINT(gtkplus2)
#endif

#include <gtk/gtk.h>

typedef enum
{
    PAGE_INTRO,
    PAGE_README,
    PAGE_OPTIONS,
    PAGE_DESTINATION,
    PAGE_PROGRESS,
    PAGE_FINAL
} WizardPages;

static GtkWidget *gtkwindow = NULL;
static GtkWidget *pagetitle = NULL;
static GtkWidget *notebook = NULL;
static GtkWidget *readme = NULL;
static GtkWidget *cancel = NULL;
static GtkWidget *back = NULL;
static GtkWidget *next = NULL;
static GtkWidget *finish = NULL;
static GtkWidget *msgbox = NULL;
static GtkWidget *destination = NULL;
static GtkWidget *progressbar = NULL;
static GtkWidget *progresslabel = NULL;
static GtkWidget *finallabel = NULL;
static GtkWidget *browse = NULL;

static volatile enum
{
    CLICK_BACK=-1,
    CLICK_CANCEL,
    CLICK_NEXT,
    CLICK_NONE
} click_value = CLICK_NONE;


static void prepare_wizard(const char *name, gint page,
                           boolean can_back, boolean can_fwd)
{
    char *markup = g_markup_printf_escaped(
                        "<span size='large' weight='bold'>%s</span>",
                        name);

    gtk_label_set_markup(GTK_LABEL(pagetitle), markup);
    g_free(markup);

    gtk_widget_set_sensitive(back, can_back);
    gtk_widget_set_sensitive(next, can_fwd);
    gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), page);

    assert(click_value == CLICK_NONE);
    assert(gtkwindow != NULL);
    assert(msgbox == NULL);
} // prepare_wizard


static int wait_event(void)
{
    int retval = 0;

    // signals fired under gtk_main_iteration can change click_value.
    gtk_main_iteration();
    if (click_value == CLICK_CANCEL)
    {
        // !!! FIXME: language.
        char *title = entry->xstrdup(entry->_("Cancel installation"));
        char *text = entry->xstrdup(entry->_("Are you sure you want to cancel installation?"));
        if (!MojoGui_gtkplus2_promptyn(title, text, false))
            click_value = CLICK_NONE;
        free(title);
        free(text);
    } // if

    assert(click_value <= CLICK_NONE);
    retval = (int) click_value;
    click_value = CLICK_NONE;
    return retval;
} // wait_event


static int pump_events(void)
{
    int retval = (int) CLICK_NONE;
    while ( (retval == ((int) CLICK_NONE)) && (gtk_events_pending()) )
        retval = wait_event();
    return retval;
} // pump_events


static int run_wizard(const char *name, gint page,
                      boolean can_back, boolean can_fwd)
{
    int retval = CLICK_NONE;
    prepare_wizard(name, page, can_back, can_fwd);
    while (retval == ((int) CLICK_NONE))
        retval = wait_event();

    assert(retval < ((int) CLICK_NONE));
    return retval;
} // run_wizard


static gboolean signal_delete(GtkWidget *w, GdkEvent *evt, gpointer data)
{
    click_value = CLICK_CANCEL;
    return TRUE;  /* eat event: default handler destroys window! */
} // signal_delete


static void signal_clicked(GtkButton *_button, gpointer data)
{
    GtkWidget *button = GTK_WIDGET(_button);
    if (button == back)
        click_value = CLICK_BACK;
    else if (button == cancel)
        click_value = CLICK_CANCEL;
    else if ((button == next) || (button == finish))
        click_value = CLICK_NEXT;
    else
    {
        assert(0 && "Unknown click event.");
    } // else
} // signal_clicked

static void signal_browse_clicked(GtkButton *_button, gpointer data)
{
    GtkWidget *dialog = gtk_file_chooser_dialog_new (
        entry->_("Installation location"),
        NULL,
        GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER,
        GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
        GTK_STOCK_OPEN, GTK_RESPONSE_ACCEPT,
        NULL);

    // !!! FIXME: should set the initial path to the existent portion
    // !!! FIXME:  of the currently suggested path.

    if (gtk_dialog_run (GTK_DIALOG (dialog)) == GTK_RESPONSE_ACCEPT) {
        gchar *filename;
        gchar *utfname;

        filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));

        utfname = g_filename_to_utf8(filename, -1, NULL, NULL, NULL);
        gtk_combo_box_prepend_text(GTK_COMBO_BOX(destination), utfname);
        gtk_combo_box_set_active(GTK_COMBO_BOX(destination), 0);

        g_free(utfname);
        g_free(filename);
    }
    
    // !!! FIXME: should append the package name to the directory they chose?
    // !!! FIXME:  This is annoying, they might have created the folder
    // !!! FIXME:  themselves in the dialog.
    // !!! FIXME: Could warn when the target directory already contains files?

    gtk_widget_destroy(dialog);
}


static uint8 MojoGui_gtkplus2_priority(boolean istty)
{
    // gnome-session exports this environment variable since 2002.
    if (getenv("GNOME_DESKTOP_SESSION_ID") != NULL)
        return MOJOGUI_PRIORITY_TRY_FIRST;

    return MOJOGUI_PRIORITY_TRY_NORMAL;
} // MojoGui_gtkplus2_priority


static boolean MojoGui_gtkplus2_init(void)
{
    int tmpargc = 0;
    char *args[] = { NULL, NULL };
    char **tmpargv = args;
    if (!gtk_init_check(&tmpargc, &tmpargv))
    {
        entry->logInfo("gtkplus2: gtk_init_check() failed, use another UI.");
        return false;
    } // if
    return true;
} // MojoGui_gtkplus2_init


static void MojoGui_gtkplus2_deinit(void)
{
    // !!! FIXME: GTK+ doesn't have a deinit function...it installs a crappy
    // !!! FIXME:  atexit() function!
} // MojoGui_gtkplus2_deinit

/**
 * 
 * @param defbutton The response ID to use when enter is pressed, or 0
 * to leave it up to GTK+.
 */
static gint do_msgbox(const char *title, const char *text,
                      GtkMessageType mtype, GtkButtonsType btype,
                      GtkResponseType defbutton,
                      void (*addButtonCallback)(GtkWidget *_msgbox))
{
    gint retval = 0;
    
    // Modal dialog, this will never be called recursively.
    assert(msgbox == NULL);

    msgbox = gtk_message_dialog_new(GTK_WINDOW(gtkwindow), GTK_DIALOG_MODAL,
                                    mtype, btype, "%s", title);
    gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(msgbox),
                                             "%s", text);

    if (defbutton)
        gtk_dialog_set_default_response(GTK_DIALOG(msgbox), defbutton);

    if (addButtonCallback != NULL)
        addButtonCallback(msgbox);

    retval = gtk_dialog_run(GTK_DIALOG(msgbox));
    gtk_widget_destroy(msgbox);
    msgbox = NULL;

    return retval;
} // do_msgbox


static void MojoGui_gtkplus2_msgbox(const char *title, const char *text)
{
    do_msgbox(title, text, GTK_MESSAGE_INFO, GTK_BUTTONS_CLOSE, 0, NULL);
} // MojoGui_gtkplus2_msgbox


static boolean MojoGui_gtkplus2_promptyn(const char *title, const char *text,
                                         boolean defval)
{
    // !!! FIXME: support defval.
    gint rc = do_msgbox(title, text, GTK_MESSAGE_QUESTION,
                        GTK_BUTTONS_YES_NO,
                        defval ? GTK_RESPONSE_YES : GTK_RESPONSE_NO,
                        NULL);

    return (rc == GTK_RESPONSE_YES);
} // MojoGui_gtkplus2_promptyn


static void promptynanButtonCallback(GtkWidget *_msgbox)
{
    char *always = entry->xstrdup(entry->_("_Always"));
    char *never = entry->xstrdup(entry->_("N_ever"));
    gtk_dialog_add_buttons(GTK_DIALOG(_msgbox),
                           GTK_STOCK_YES, GTK_RESPONSE_YES,
                           GTK_STOCK_NO, GTK_RESPONSE_NO,
                           always, 1,
                           never, 0,
                           NULL);

    free(always);
    free(never);
} // promptynanButtonCallback


static MojoGuiYNAN MojoGui_gtkplus2_promptynan(const char *title,
                                               const char *text,
                                               boolean defval)
{
    // !!! FIXME: support defval.
    const gint rc = do_msgbox(title, text, GTK_MESSAGE_QUESTION,
                              GTK_BUTTONS_NONE,
                              defval ? GTK_RESPONSE_YES : GTK_RESPONSE_NO,
                              promptynanButtonCallback);
    switch (rc)
    {
        case GTK_RESPONSE_YES: return MOJOGUI_YES;
        case GTK_RESPONSE_NO: return MOJOGUI_NO;
        case 1: return MOJOGUI_ALWAYS;
        case 0: return MOJOGUI_NEVER;
    } // switch

    assert(false && "BUG: unhandled case in switch statement");
    return MOJOGUI_NO;  // just in case.
} // MojoGui_gtkplus2_promptynan


static GtkWidget *create_button(GtkWidget *box, const char *iconname,
                                const char *text,
                                void (*signal_callback)
                                    (GtkButton *button, gpointer data))
{
    GtkWidget *button = gtk_button_new_with_mnemonic(text);
    GtkWidget *image = gtk_image_new_from_stock(iconname, GTK_ICON_SIZE_BUTTON);
    gtk_button_set_image (GTK_BUTTON(button), image);
    gtk_widget_show(button);
    gtk_box_pack_start(GTK_BOX(box), button, FALSE, FALSE, 6);
    gtk_signal_connect(GTK_OBJECT(button), "clicked",
                      GTK_SIGNAL_FUNC(signal_callback), NULL);
    return button;
} // create_button


GtkWidget *create_gtkwindow(const char *title)
{
    GtkWidget *window;
    GtkWidget *widget;
    GtkWidget *box;
    GtkWidget *alignment;
    GtkWidget *hbox;

    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), title);
    gtk_container_set_border_width(GTK_CONTAINER(window), 8);

    GdkPixbuf *icon = gtk_icon_theme_load_icon (gtk_icon_theme_get_default (),
                                                "system-software-installer",
                                                48, 0, NULL);
    if (icon)
        gtk_window_set_icon(GTK_WINDOW(window), icon);

    box = gtk_vbox_new(FALSE, 6);
    gtk_widget_show(box);
    gtk_container_add(GTK_CONTAINER(window), box);

    pagetitle = gtk_label_new("");
    gtk_widget_show(pagetitle);
    gtk_box_pack_start(GTK_BOX(box), pagetitle, FALSE, TRUE, 16);
    
    notebook = gtk_notebook_new();
    gtk_widget_show(notebook);
    gtk_container_set_border_width(GTK_CONTAINER(notebook), 0);
    gtk_box_pack_start(GTK_BOX(box), notebook, TRUE, TRUE, 0);
    gtk_notebook_set_show_tabs(GTK_NOTEBOOK(notebook), FALSE);
    gtk_notebook_set_show_border(GTK_NOTEBOOK(notebook), FALSE);
    gtk_widget_set_size_request(notebook,
                                (gint) (((float) gdk_screen_width()) * 0.3),
                                (gint) (((float) gdk_screen_height()) * 0.3));

    widget = gtk_hbutton_box_new();
    gtk_widget_show(widget);
    gtk_box_pack_start(GTK_BOX(box), widget, FALSE, FALSE, 0);
    gtk_button_box_set_layout(GTK_BUTTON_BOX (widget), GTK_BUTTONBOX_END);
    gtk_button_box_set_child_ipadding(GTK_BUTTON_BOX (widget), 6, 0);
    gtk_button_box_set_spacing(GTK_BUTTON_BOX (widget), 6);

    box = widget;
    cancel = create_button(box, "gtk-cancel", entry->_("Cancel"), signal_clicked);
    back = create_button(box, "gtk-go-back", entry->_("Back"), signal_clicked);
    next = create_button(box, "gtk-go-forward", entry->_("Next"), signal_clicked);
    finish = create_button(box, "gtk-goto-last", entry->_("Finish"), signal_clicked);
    gtk_widget_hide(finish);

    // !!! FIXME: intro page.
    widget = gtk_vbox_new(FALSE, 0);
    gtk_widget_show(widget);
    gtk_container_add(GTK_CONTAINER(notebook), widget);

    // README/EULA page.
    widget = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(
        GTK_SCROLLED_WINDOW(widget),
        GTK_POLICY_AUTOMATIC, GTK_POLICY_ALWAYS);
    gtk_scrolled_window_set_shadow_type(
        GTK_SCROLLED_WINDOW(widget),
        GTK_SHADOW_IN);
    gtk_widget_show(widget);
    gtk_container_add(GTK_CONTAINER(notebook), widget);

    readme = gtk_text_view_new();
    gtk_widget_show(readme);
    gtk_container_add(GTK_CONTAINER(widget), readme);
    gtk_text_view_set_editable(GTK_TEXT_VIEW(readme), FALSE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(readme), GTK_WRAP_NONE);
    gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(readme), FALSE);
    gtk_text_view_set_left_margin(GTK_TEXT_VIEW(readme), 4);
    gtk_text_view_set_right_margin(GTK_TEXT_VIEW(readme), 4);

    // !!! FIXME: options page.
    box = gtk_vbox_new(FALSE, 0);
    gtk_widget_show(box);
    gtk_container_add(GTK_CONTAINER(notebook), box);

    // Destination page
    box = gtk_vbox_new(FALSE, 0);
    gtk_widget_show(box);

    hbox = gtk_hbox_new (FALSE, 6);
    widget = gtk_label_new("Folder:");
    gtk_widget_show(widget);
    gtk_box_pack_start(GTK_BOX(hbox), widget, FALSE, TRUE, 0);
    gtk_label_set_justify(GTK_LABEL(widget), GTK_JUSTIFY_CENTER);
    gtk_label_set_line_wrap(GTK_LABEL(widget), FALSE);
    alignment = gtk_alignment_new(0.5, 0.5, 1, 0);
    destination = gtk_combo_box_entry_new_text();
    gtk_container_add(GTK_CONTAINER(alignment), destination);
    gtk_box_pack_start(GTK_BOX(hbox), alignment, TRUE, TRUE, 0);
    browse = create_button(hbox, "gtk-open",
                           entry->_("B_rowse..."), signal_browse_clicked);
    gtk_widget_show_all (hbox);
    gtk_box_pack_start(GTK_BOX(box), hbox, FALSE, FALSE, 0);
    gtk_container_add(GTK_CONTAINER(notebook), box);    

    // Progress page
    box = gtk_vbox_new(FALSE, 6);
    gtk_widget_show(box);
    alignment = gtk_alignment_new(0.5, 0.5, 1, 0);
    gtk_widget_show(alignment);
    progressbar = gtk_progress_bar_new();
    gtk_widget_show(progressbar);
    gtk_container_add(GTK_CONTAINER(alignment), progressbar);
    gtk_box_pack_start(GTK_BOX(box), alignment, FALSE, TRUE, 0);
    progresslabel = gtk_label_new("");
    gtk_widget_show(progresslabel);
    gtk_box_pack_start(GTK_BOX(box), progresslabel, FALSE, TRUE, 0);
    gtk_label_set_justify(GTK_LABEL(progresslabel), GTK_JUSTIFY_LEFT);
    gtk_label_set_line_wrap(GTK_LABEL(progresslabel), FALSE);
    gtk_container_add(GTK_CONTAINER(notebook), box);

    // !!! FIXME: final page.
    widget = gtk_vbox_new(FALSE, 0);
    gtk_widget_show(widget);
    gtk_container_add(GTK_CONTAINER(notebook), widget);
    finallabel = gtk_label_new("");
    gtk_widget_show(finallabel);
    gtk_box_pack_start(GTK_BOX(widget), finallabel, FALSE, TRUE, 0);
    gtk_label_set_justify(GTK_LABEL(finallabel), GTK_JUSTIFY_LEFT);
    gtk_label_set_line_wrap(GTK_LABEL(finallabel), FALSE);

    gtk_signal_connect(GTK_OBJECT(window), "delete-event",
                       GTK_SIGNAL_FUNC(signal_delete), NULL);

    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    gtk_widget_show(window);
    return window;
} // create_gtkwindow


static boolean MojoGui_gtkplus2_start(const char *title, const char *splash)
{
    gtkwindow = create_gtkwindow(title);
    return (gtkwindow != NULL);
} // MojoGui_gtkplus2_start


static void MojoGui_gtkplus2_stop(void)
{
    assert(msgbox == NULL);
    if (gtkwindow != NULL)
        gtk_widget_destroy(gtkwindow);

    gtkwindow = NULL;
    pagetitle = NULL;
    finallabel = NULL;
    progresslabel = NULL;
    progressbar = NULL;
    destination = NULL;
    notebook = NULL;
    readme = NULL;
    cancel = NULL;
    back = NULL;
    next = NULL;
    finish = NULL;
} // MojoGui_gtkplus2_stop


static int MojoGui_gtkplus2_readme(const char *name, const uint8 *data,
                                   size_t datalen, boolean can_back,
                                   boolean can_fwd)
{
    GtkTextBuffer *textbuf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(readme));
    gtk_text_buffer_set_text(textbuf, (const gchar *) data, datalen);
    return run_wizard(name, PAGE_README, can_back, can_fwd);
} // MojoGui_gtkplus2_readme


static void set_option_tree_sensitivity(MojoGuiSetupOptions *opts, boolean val)
{
    if (opts != NULL)
    {
        gtk_widget_set_sensitive((GtkWidget *) opts->guiopaque, val);
        set_option_tree_sensitivity(opts->next_sibling, val);
        set_option_tree_sensitivity(opts->child, val && opts->value);
    } // if
} // set_option_tree_sensitivity


static void signal_option_toggled(GtkToggleButton *toggle, gpointer data)
{
    MojoGuiSetupOptions *opts = (MojoGuiSetupOptions *) data;
    const boolean enabled = gtk_toggle_button_get_active(toggle);
    opts->value = enabled;
    set_option_tree_sensitivity(opts->child, enabled);
} // signal_option_toggled


static GtkWidget *new_option_level(GtkWidget *box)
{
    GtkWidget *alignment = gtk_alignment_new(0.0, 0.5, 0, 0);
    GtkWidget *retval = gtk_vbox_new(FALSE, 0);
    gtk_alignment_set_padding(GTK_ALIGNMENT(alignment), 0, 0, 15, 0);
    gtk_widget_show(alignment);
    gtk_widget_show(retval);
    gtk_container_add(GTK_CONTAINER(alignment), retval);
    gtk_box_pack_start(GTK_BOX(box), alignment, TRUE, TRUE, 0);
    return retval;
} // new_option_level


static void build_options(MojoGuiSetupOptions *opts, GtkWidget *box,
                          gboolean sensitive)
{
    if (opts != NULL)
    {
        GtkWidget *widget;
        if (opts->is_group_parent)
        {
            MojoGuiSetupOptions *kids = opts->child;
            GtkWidget *childbox = NULL;
            GtkWidget *alignment = gtk_alignment_new(0.0, 0.5, 0, 0);
            gtk_widget_show(alignment);
            widget = gtk_label_new(opts->description);
            opts->guiopaque = widget;
            gtk_widget_set_sensitive(widget, sensitive);
            gtk_widget_show(widget);
            gtk_label_set_justify(GTK_LABEL(widget), GTK_JUSTIFY_LEFT);
            gtk_label_set_line_wrap(GTK_LABEL(widget), FALSE);
            gtk_container_add(GTK_CONTAINER(alignment), widget);
            gtk_box_pack_start(GTK_BOX(box), alignment, FALSE, TRUE, 0);

            widget = NULL;
            childbox = new_option_level(box);
            while (kids)
            {
                widget = gtk_radio_button_new_with_label_from_widget(
                                                    GTK_RADIO_BUTTON(widget),
                                                    kids->description);
                kids->guiopaque = widget;
                gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(widget),
                                             kids->value);
                gtk_widget_set_sensitive(widget, sensitive);
                gtk_widget_show(widget);
                gtk_box_pack_start(GTK_BOX(childbox), widget, FALSE, TRUE, 0);
                gtk_signal_connect(GTK_OBJECT(widget), "toggled",
                                 GTK_SIGNAL_FUNC(signal_option_toggled), kids);
                if (kids->child != NULL)
                {
                    build_options(kids->child, new_option_level(childbox),
                                  sensitive);
                } // if
                kids = kids->next_sibling;
            } // while
        } // if

        else
        {
            widget = gtk_check_button_new_with_label(opts->description);
            opts->guiopaque = widget;
            gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(widget),
                                         opts->value);
            gtk_widget_set_sensitive(widget, sensitive);
            gtk_widget_show(widget);
            gtk_box_pack_start(GTK_BOX(box), widget, FALSE, TRUE, 0);
            gtk_signal_connect(GTK_OBJECT(widget), "toggled",
                               GTK_SIGNAL_FUNC(signal_option_toggled), opts);
            if (opts->child != NULL)
            {
                build_options(opts->child, new_option_level(box),
                                ((sensitive) && (opts->value)) );
            } // if
        } // else

        build_options(opts->next_sibling, box, sensitive);
    } // if
} // build_options


static int MojoGui_gtkplus2_options(MojoGuiSetupOptions *opts,
                                    boolean can_back, boolean can_fwd)
{
    int retval;
    GtkWidget *widget;
    GtkWidget *box;
    GtkWidget *page;  // this is a vbox.

    page = gtk_notebook_get_nth_page(GTK_NOTEBOOK(notebook), PAGE_OPTIONS);
    box = gtk_vbox_new(FALSE, 0);
    gtk_widget_show(box);
    gtk_box_pack_start(GTK_BOX(page), box, FALSE, FALSE, 0);

    widget = gtk_label_new("!!! FIXME: this GUI stage is a placeholder");
    gtk_widget_show(widget);
    gtk_box_pack_start(GTK_BOX(box), widget, FALSE, TRUE, 0);
    gtk_label_set_justify(GTK_LABEL(widget), GTK_JUSTIFY_CENTER);
    gtk_label_set_line_wrap(GTK_LABEL(widget), TRUE);

    build_options(opts, box, TRUE);

    // !!! FIXME: better text.
    retval = run_wizard(entry->_("Options"), PAGE_OPTIONS, can_back, can_fwd);
    gtk_widget_destroy(box);
    return retval;
} // MojoGui_gtkplus2_options


static char *MojoGui_gtkplus2_destination(const char **recommends, int recnum,
                                          int *command, boolean can_back,
                                          boolean can_fwd)
{
    GtkComboBox *combo = GTK_COMBO_BOX(destination);
    gchar *str = NULL;
    char *retval = NULL;
    int i;

    for (i = 0; i < recnum; i++)
        gtk_combo_box_prepend_text(combo, recommends[i]);
    gtk_combo_box_set_active (combo, 0);

    *command = run_wizard(entry->_("Installation location"), PAGE_DESTINATION,
                          can_back, can_fwd);

    str = gtk_combo_box_get_active_text(combo);
    if ((str == NULL) || (*str == '\0'))
        *command = 0;
    else
    {
        retval = entry->xstrdup(str);
        g_free(str);
    } // else

    for (i = recnum-1; i >= 0; i--)
        gtk_combo_box_remove_text(combo, i);

    return retval;
} // MojoGui_gtkplus2_destination


static boolean MojoGui_gtkplus2_insertmedia(const char *medianame)
{
    gint rc = 0;
    // !!! FIXME: Use stock GTK icon for "media"?
    // !!! FIXME: better text.
    const char *title = entry->_("Media change");
    // !!! FIXME: better text.
    const char *fmt = entry->_("Please insert '%s'");
    size_t len = strlen(fmt) + strlen(medianame) + 1;
    char *text = (char *) entry->xmalloc(len);
    snprintf(text, len, fmt, medianame);
    rc = do_msgbox(title, text, GTK_MESSAGE_WARNING,
                   GTK_BUTTONS_OK_CANCEL, GTK_RESPONSE_OK, NULL);
    return (rc == GTK_RESPONSE_OK);
} // MojoGui_gtkplus2_insertmedia


static boolean MojoGui_gtkplus2_progress(const char *type, const char *component,
                                         int percent, const char *item)
{
    static uint32 lastTicks = 0;
    const uint32 ticks = entry->ticks();
    int rc;

    if ((ticks - lastTicks) > 200)  // just not to spam this...
    {
        GtkProgressBar *progress = GTK_PROGRESS_BAR(progressbar);
        if (percent < 0)
            gtk_progress_bar_pulse(progress);
        else
            gtk_progress_bar_set_fraction(progress, ((gdouble) percent) / 100.0);

        gtk_progress_bar_set_text(progress, component);
        gtk_label_set_text(GTK_LABEL(progresslabel), item);
        lastTicks = ticks;
    } // if

    prepare_wizard(type, PAGE_PROGRESS, false, false);
    rc = pump_events();
    assert( (rc == ((int) CLICK_CANCEL)) || (rc == ((int) CLICK_NONE)) );
    return (rc != CLICK_CANCEL);
} // MojoGui_gtkplus2_progress


static void MojoGui_gtkplus2_final(const char *msg)
{
    gtk_widget_hide(next);
    gtk_widget_show(finish);
    gtk_widget_set_sensitive(cancel, FALSE);
    gtk_label_set_text(GTK_LABEL(finallabel), msg);
    run_wizard(entry->_("Finish"), PAGE_FINAL, false, true);
} // MojoGui_gtkplus2_final

// end of gui_gtkplus2.c ...

