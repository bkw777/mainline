# Makefile for "mainline"

SHELL := /bin/bash
CFLAGS := -O2
VALACFLAGS :=
#VALACFLAGS += -g

# compile-time options
#VALACFLAGS += -D LOCK_TOGGLES_IN_KERNEL_COLUMN
#    Put the lock/unlock checkboxes inside the kernel version column instead of
#    in their own column. The display is neater, but you can't sort by locked
#    status to gather all the locked kernels together by clicking the header.
#    TODO customized checkbox lock icon since there is no "Lock" column header label
#    TODO cycle sorting between version number and locked status every 2nd time header is clicked
#         version-up -> version-dn -> locked-up -> locked-dn -> repeat
#VALACFLAGS += -D DISPLAY_VERSION_SORT
#    Use the internally constructed version_sort string for display.
#    Default is version_main which from the mainline-ppa index.html.

prefix := /usr
bindir := $(prefix)/bin
sharedir := $(prefix)/share
libdir := $(prefix)/lib
localedir := $(sharedir)/locale
launcherdir := $(sharedir)/applications
#polkitdir := $(sharedir)/polkit-1/actions
mandir := $(sharedir)/man
man1dir := $(mandir)/man1

vte := vte-2.91
glib := glib-2.0
gio-unix := gio-unix-2.0
gtk+ := gtk+-3.0
json-glib := json-glib-1.0
gee := gee-0.8

#VALACFLAGS += $(shell pkg-config $(json-glib) --atleast-version=1.6 && echo " -D HAVE_GLIB_JSON_1_6")
VALACFLAGS += $(shell pkg-config $(vte) --atleast-version=0.72 && echo " -D VTE_0_72")
VALACFLAGS += $(shell pkg-config $(glib) --atleast-version=2.56 || echo " --target-glib 2.32")

include BRANDING.mak
BRANDING_VERSION := $(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_MICRO)
build_symbols := -X -D'INSTALL_PREFIX="$(prefix)"' \
	-X -D'BRANDING_SHORTNAME="$(BRANDING_SHORTNAME)"' \
	-X -D'BRANDING_LONGNAME="$(BRANDING_LONGNAME)"' \
	-X -D'BRANDING_VERSION="$(BRANDING_VERSION)"' \
	-X -D'BRANDING_COPYRIGHT="$(BRANDING_COPYRIGHT)"' \
	-X -D'BRANDING_AUTHORNAME="$(BRANDING_AUTHORNAME)"' \
	-X -D'BRANDING_AUTHOREMAIL="$(BRANDING_AUTHOREMAIL)"' \
	-X -D'BRANDING_WEBSITE="$(BRANDING_WEBSITE)"' \
	-X -D'GETTEXT_PACKAGE="$(BRANDING_SHORTNAME)"'

misc_files := README.md \
	$(BRANDING_SHORTNAME).desktop \
	debian/control \
	debian/copyright \
#	share/polkit-1/actions/$(BRANDING_SHORTNAME).policy

common_vala_files := src/Common/*.vala src/lib/*.vala
tui_vala_files := src/Console/*.vala
gui_vala_files := src/Gtk/*.vala

po_files := po/*.po
pot_file := po/messages.pot

DEB_BUILD_NUMBER := 0000
DEB_PKG_VERSION := $(BRANDING_VERSION)
-include .deb_build_number.mak

dist := $(shell lsb_release -sc)
arch := $(shell dpkg --print-architecture)
pkg_version = $(shell dpkg-parsechangelog -S Version)
dsc_file = release/deb-src/$(BRANDING_SHORTNAME)_$(pkg_version).dsc
deb_file = release/deb/$(BRANDING_SHORTNAME)_$(pkg_version).$(DEB_BUILD_NUMBER)_$(dist)_$(arch).deb

################################################################################

# Override debhelper>9 using make -jN in "make deb", which breaks vala unless you do
# https://wiki.gnome.org/Projects/Vala/Documentation/ParallelBuilds
# which is ridiculous nonsense
.NOTPARALLEL:

.PHONY: all
all: $(BRANDING_SHORTNAME) $(BRANDING_SHORTNAME)-gtk

$(BRANDING_SHORTNAME): $(misc_files) $(common_vala_files) $(tui_vala_files) TRANSLATORS
	valac $(VALACFLAGS) -X -w $(build_symbols) --Xcc="-lm" \
		--pkg $(glib) --pkg $(gio-unix) --pkg posix --pkg $(gee) --pkg $(json-glib) \
		$(common_vala_files) $(tui_vala_files) -o $(@)

# Override debhelper setting LANG=C & LC_ALL=C in "make deb"
# which causes valac to die on the non-ascii in -D'TRANSLATORS=...'
$(BRANDING_SHORTNAME)-gtk: $(misc_files) $(common_vala_files) $(gui_vala_files) TRANSLATORS
	LANG=C.UTF-8;LC_ALL=$${LANG};LANGUAGE=$${LANG};T=;while read t;do T+="$$t\n";done<TRANSLATORS;set -x; \
		valac $(VALACFLAGS) -X -w $(build_symbols) -X -D'TRANSLATORS="'"$${T:0:-2}"'"' --Xcc="-lm" \
		--pkg $(glib) --pkg $(gio-unix) --pkg posix --pkg $(gee) --pkg $(json-glib) --pkg $(gtk+) --pkg $(vte) --pkg x11 \
		$(common_vala_files) $(gui_vala_files) -o $(@)

$(misc_files): %: %.src BRANDING.mak
	sed -e 's|BRANDING_SHORTNAME|$(BRANDING_SHORTNAME)|g' \
		-e 's|BRANDING_LONGNAME|$(BRANDING_LONGNAME)|g' \
		-e 's|BRANDING_VERSION|$(BRANDING_VERSION)|g' \
		-e 's|BRANDING_COPYRIGHT|$(BRANDING_COPYRIGHT)|g' \
		-e 's|BRANDING_AUTHORNAME|$(BRANDING_AUTHORNAME)|g' \
		-e 's|BRANDING_AUTHOREMAIL|$(BRANDING_AUTHOREMAIL)|g' \
		-e 's|BRANDING_WEBSITE|$(BRANDING_WEBSITE)|g' \
		-e 's|BRANDING_GITREPO|$(BRANDING_GITREPO)|g' \
		$(@).src >$(@)

$(pot_file): $(common_vala_files) $(tui_vala_files) $(gui_vala_files)
	xgettext \
		--package-name="$(BRANDING_SHORTNAME)" \
		--package-version="$(BRANDING_VERSION)" \
		--copyright-holder="" \
		--from-code=UTF-8 \
		--language=Vala \
		--add-comments="Translators:" \
		--no-wrap \
		--output=$(@) \
		$(common_vala_files) $(tui_vala_files) $(gui_vala_files)

$(po_files): %: $(pot_file)
	msgmerge --backup=none --previous --no-fuzzy-matching --update --no-wrap -v $(@) $(pot_file)
	msgattrib --output-file=$(@) --no-obsolete --previous --clear-fuzzy --empty $(@)
	@touch $(@)

TRANSLATORS: $(po_files)
	grep '^"Last-Translator: ' $(po_files) |while IFS='/.:' read x l x x n ;do echo "$${l}:$${n%\n*}" ;done >$(@)

.PHONY: translations
translations: TRANSLATORS

.PHONY: clean
clean:
	rm -rfv release *.c *.o
	rm -fv $(BRANDING_SHORTNAME) $(BRANDING_SHORTNAME)-gtk

.PHONY: install
install: all
	mkdir -p "$(DESTDIR)$(bindir)"
	mkdir -p "$(DESTDIR)$(sharedir)/pixmaps/$(BRANDING_SHORTNAME)"
	mkdir -p "$(DESTDIR)$(libdir)/$(BRANDING_SHORTNAME)"
	mkdir -p "$(DESTDIR)$(man1dir)"
	mkdir -p "$(DESTDIR)$(launcherdir)"
#	mkdir -p "$(DESTDIR)$(polkitdir)"
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(sharedir)" share/*
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(libdir)/$(BRANDING_SHORTNAME)" lib/*
#	install -m 0644 share/polkit-1/actions/$(BRANDING_SHORTNAME).policy "$(DESTDIR)$(polkitdir)"
	install -m 0755 $(BRANDING_SHORTNAME).desktop "$(DESTDIR)$(launcherdir)"
	for p in $(po_files) ; do l=$${p##*/} l=$${l%.*}; echo -n "$${l}: "; \
		mkdir -p "$(DESTDIR)$(localedir)/$${l}/LC_MESSAGES"; \
		msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/$${l}/LC_MESSAGES/$(BRANDING_SHORTNAME).mo" $${p}; \
	done
	install -m 0755 $(BRANDING_SHORTNAME) "$(DESTDIR)$(bindir)"
	install -m 0755 $(BRANDING_SHORTNAME)-gtk "$(DESTDIR)$(bindir)"

.PHONY: uninstall
uninstall:
	rm -f $(DESTDIR)$(bindir)/$(BRANDING_SHORTNAME) $(DESTDIR)$(bindir)/$(BRANDING_SHORTNAME)-gtk
	rm -f $(DESTDIR)$(sharedir)/pixmaps/$(BRANDING_SHORTNAME).*
	rm -rf $(DESTDIR)$(sharedir)/pixmaps/$(BRANDING_SHORTNAME)
	rm -rf $(DESTDIR)$(libdir)/$(BRANDING_SHORTNAME)
#	rm -f $(DESTDIR)$(polkitdir)/$(BRANDING_SHORTNAME).policy
	rm -f $(DESTDIR)$(launcherdir)/$(BRANDING_SHORTNAME).desktop
	rm -f $(DESTDIR)$(localedir)/*/LC_MESSAGES/$(BRANDING_SHORTNAME).mo
	rm -f $(DESTDIR)/home/*/.config/$(BRANDING_SHORTNAME)/$(BRANDING_SHORTNAME)-notify.sh
	rm -f $(DESTDIR)/home/*/.config/autostart/$(BRANDING_SHORTNAME).desktop

.PHONY: pbuilder-dist
pbuilder-dist:
	@which pbuilder-dist >/dev/null || { echo "Missing pbuilder-dist. apt install ubuntu-dev-tools" ;false ; }

.PHONY: deb-src
deb-src: $(dsc_file)

.PHONY: dsc
dsc: $(dsc_file)

$(dsc_file): debian/changelog debian/compat debian/rules $(misc_files) $(common_vala_files) $(gui_vala_files) AUTHORS INSTALL settings.md Makefile BRANDING.mak
	@[[ "$(pkg_version)" == "$(BRANDING_VERSION)" ]] || { echo -e "Version number in debian/changelog ($(pkg_version)) does not match BRANDING.mak ($(BRANDING_VERSION)).\n(Maybe need to run \"dch\"?)" >&2 ; exit 1 ; }
	$(MAKE) clean
	dpkg-source --build .
	mkdir -pv release/deb-src
	mv -fv ../$(BRANDING_SHORTNAME)_$(pkg_version).dsc release/deb-src/
	mv -fv ../$(BRANDING_SHORTNAME)_$(pkg_version).tar.* release/deb-src/
	ls -l release/deb-src

.PHONY: deb
deb: $(deb_file)

.PHONY: deb_env_create
deb_env_create: pbuilder-dist
	pbuilder-dist $(dist) $(arch) create

.PHONY: deb_env_update
deb_env_update: pbuilder-dist
	pbuilder-dist $(dist) $(arch) update

$(deb_file): $(dsc_file) pbuilder-dist
	mkdir -pv release/deb
	pbuilder-dist $(dist) $(arch) build $(dsc_file) --buildresult release/deb
	mv -fv release/deb/$(BRANDING_SHORTNAME)_$(pkg_version)_$(arch).deb $(@)
	ls -lv release/deb

.PHONY: install-deb
install-deb: $(deb_file)
	sudo dpkg -i $(deb_file)

.PHONY: uninstall-deb
uninstall-deb:
	sudo dpkg -r $(BRANDING_SHORTNAME)

.PHONY: changelog
changelog: debian/changelog

debian/changelog: $(misc_files)
	dch --controlmaint --no-auto-nmu --package $(BRANDING_SHORTNAME) --newversion $(BRANDING_VERSION)

# PHONY to force it to always run
.PHONY: deb_build_number
deb_build_number: debian/changelog
	{ typeset -i n=$(DEB_BUILD_NUMBER) ;((n++)) ;[[ "_$(DEB_PKG_VERSION)" == "_$(pkg_version)" ]] || n=0 ; \
	printf '# This file is generated by Makefile "make $(@)"\nDEB_PKG_VERSION = $(pkg_version)\nDEB_BUILD_NUMBER = %04u\n' $$n > .$(@).mak ; }

# child process to re-load .deb_build_number.mak after updating it
.PHONY: release_deb
release_deb: deb_build_number clean
	$(MAKE) deb

# disable some built-in rules
Makefile:
	@echo $(@)

%.mak:
	@echo $(@)

%.src:
	@echo $(@)

%.vala:
	@echo $(@)
