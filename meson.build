
project('com.github.bkw777.mainline', 'vala', 'c', version: '1.0.12')

# these are Meson modules
gnome = import('gnome')
i18n = import('i18n')


# common dirs
prefix = get_option('prefix')
datadir = join_paths(prefix, get_option('datadir'))
libdir = join_paths(prefix, get_option('libdir'))
icondir = join_paths(datadir, 'icons', 'hicolor')

# and these are project dependencies
glib = dependency('glib-2.0')
gtk = dependency('gtk+-3.0')
gee = dependency('gee-0.8')
gio = dependency('gio-2.0')
vte = dependency('vte-2.91')
json = dependency('json-glib-1.0')


config_data = configuration_data()
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())

configure_file(output: 'config.h', configuration: config_data)
config_h_dir = include_directories('.')

# css_gresource = gnome.compile_resources(
#     'gresource_css', 'data/css.gresource.xml',
#     source_dir: 'data',
#     c_name: 'as2'
# )

c_args = [
    '-include', 'config.h',
    '-w',
    # '-g',
    # '--save-temps'
]

executable(
    meson.project_name(),
    # icons_gresource,
    # css_gresource,
    
    'src/Common/DownloadManager.vala',
    'src/Common/LinuxKernel.vala',
    'src/Common/Main.vala',
    'src/Common/OSDNotify.vala',
    'src/Common/Package.vala',

    'src/Console/AppConsole.vala',

    'src/Gtk/AppGtk.vala',
    'src/Gtk/MainWindow.vala',
    'src/Gtk/ProgressWindow.vala',
    'src/Gtk/SettingsDialog.vala',
    'src/Gtk/TerminalWindow.vala',

    # Widgets related only to ProcessInfoView
    'src/Utility/Gtk/AboutWindow.vala',
    'src/Utility/Gtk/CustomMessageDialog.vala',
    'src/Utility/Gtk/GtkHelper.vala',
    'src/Utility/AsyncTask.vala',
    'src/Utility/TeeJee.FileSystem.vala',
    'src/Utility/TeeJee.Json.vala',
    'src/Utility/TeeJee.Logging.vala',
    'src/Utility/TeeJee.Misc.vala',
    'src/Utility/TeeJee.Process.vala',
    'src/Utility/TeeJee.System.vala',


    c_args: c_args,
    dependencies: [
        glib,
        gtk,
        gee,
        gio,
        vte,
        json
    ],
    install: true
)

# Add in a post install script
meson.add_install_script('meson/post_install.py')

subdir('data')
subdir('po')
