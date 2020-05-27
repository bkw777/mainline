icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(icondir, i + 'x' + i, 'apps')
    )
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(icondir, i + 'x' + i + '@2', 'apps')
    )
endforeach

# we can save window state here
# install_data(
#     meson.project_name() + '.gschema.xml',
#     install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
# )

i18n.merge_file(
    input: meson.project_name() + '.desktop.in',
    output: meson.project_name() + '.desktop',
    po_dir: join_paths(meson.source_root(), 'po', 'extra'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(datadir, 'applications')
)

# i18n.merge_file(
#     input: meson.project_name() + '.appdata.xml.in',
#     output: meson.project_name() + '.appdata.xml',
#     po_dir: join_paths(meson.source_root(), 'po', 'extra'),
#     install: true,
#     install_dir: join_paths(datadir, 'metainfo')
# )