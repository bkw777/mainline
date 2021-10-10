# Makefile for "mainline"

# url to ubuntu mainline kernels
URI_KERNEL_UBUNTU_MAINLINE := https://kernel.ubuntu.com/~kernel-ppa/mainline/

SHELL := /bin/bash
CFLAGS := --std=c99

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

include BRANDING.mak
BRANDING_VERSION := $(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_MICRO)
build_symbols := -X -D'INSTALL_PREFIX="$(prefix)"' \
	-X -D'BRANDING_SHORTNAME="$(BRANDING_SHORTNAME)"' \
	-X -D'BRANDING_LONGNAME="$(BRANDING_LONGNAME)"' \
	-X -D'BRANDING_VERSION="$(BRANDING_VERSION)"' \
	-X -D'BRANDING_AUTHORNAME="$(BRANDING_AUTHORNAME)"' \
	-X -D'BRANDING_AUTHOREMAIL="$(BRANDING_AUTHOREMAIL)"' \
	-X -D'BRANDING_WEBSITE="$(BRANDING_WEBSITE)"' \
	-X -D'GETTEXT_PACKAGE="$(BRANDING_SHORTNAME)"' \
	-X -D'URI_KERNEL_UBUNTU_MAINLINE="$(URI_KERNEL_UBUNTU_MAINLINE)"'

misc_files := README.md \
	INSTALL \
	$(BRANDING_SHORTNAME).desktop \
	debian/control \
	debian/copyright \
#	share/polkit-1/actions/$(BRANDING_SHORTNAME).policy

common_vala_files := src/Common/*.vala src/Utility/*.vala
tui_vala_files := src/Console/*.vala
gui_vala_files := src/Gtk/*.vala src/Utility/Gtk/*.vala

po_files := po/*.po
pot_file := po/messages.pot

include .deb_build_number.mak
host_dist := $(shell lsb_release -sc)
host_arch := $(shell dpkg --print-architecture)
pkg_version = $(shell dpkg-parsechangelog -S Version)
dsc_file = release/deb-src/$(BRANDING_SHORTNAME)_$(pkg_version).dsc
deb_file = release/deb/$(BRANDING_SHORTNAME)_$(pkg_version).$(DEB_BUILD_NUMBER)_$(host_arch).deb

################################################################################

.PHONY: all
all: $(BRANDING_SHORTNAME) $(BRANDING_SHORTNAME)-gtk

$(BRANDING_SHORTNAME)-gtk: $(misc_files) $(common_vala_files) $(gui_vala_files) $(po_files)
	valac -X -w $(build_symbols) --Xcc="-lm" \
		--pkg $(glib) --pkg $(gio-unix) --pkg posix --pkg $(gee) --pkg $(json-glib) --pkg $(gtk+) --pkg $(vte) \
		$(common_vala_files) $(gui_vala_files) -o $(@)

$(BRANDING_SHORTNAME): $(misc_files) $(common_vala_files) $(tui_vala_files) $(po_files)
	valac -X -w $(build_symbols) --Xcc="-lm" \
		--pkg $(glib) --pkg $(gio-unix) --pkg posix --pkg $(gee) --pkg $(json-glib) \
		$(common_vala_files) $(tui_vala_files) -o $(@)

$(misc_files): %: %.src BRANDING.mak
	sed -e 's/BRANDING_SHORTNAME/$(BRANDING_SHORTNAME)/g' \
		-e ';s/BRANDING_LONGNAME/$(BRANDING_LONGNAME)/g' \
		-e ';s/BRANDING_AUTHORNAME/$(BRANDING_AUTHORNAME)/g' \
		-e ';s/BRANDING_AUTHOREMAIL/$(BRANDING_AUTHOREMAIL)/g' \
		-e ';s|BRANDING_WEBSITE|$(BRANDING_WEBSITE)|g' \
		-e ';s/BRANDING_VERSION/$(BRANDING_VERSION)/g' \
		-e ';s|BRANDING_GITREPO|$(BRANDING_GITREPO)|g' \
		$(@).src >$(@)
#		-e ';s|DEST_BIN_DIR|$(DESTDIR)$(bindir)|g'

$(pot_file): $(common_vala_files) $(tui_vala_files) $(gui_vala_files)
	xgettext \
		--sort-by-file \
		--package-name="$(BRANDING_SHORTNAME)" \
		--package-version="$(BRANDING_VERSION)" \
		--language=Vala \
		--output=$(@) \
		$(common_vala_files) $(tui_vala_files) $(gui_vala_files)

$(po_files): %: $(pot_file)
	msgmerge --backup=none --update -v $(@) $(pot_file)
	msgattrib --output-file=$(@) --no-obsolete $(@)
	@touch $(@)

TRANSLATORS: $(po_files)
	grep '^"Last-Translator: ' $(po_files) |while IFS='/.:' read x l x x n ;do echo "$${l}:$${n%\n*}" ;done >$(@)

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
	for p in $(po_files) ; do \
		l=$${p##*/} l=$${l%.*}; \
		mkdir -p "$(DESTDIR)$(localedir)/$${l}/LC_MESSAGES"; \
		msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/$${l}/LC_MESSAGES/$(BRANDING_SHORTNAME).mo" $${p} ; \
	done
	install -m 0755 $(BRANDING_SHORTNAME) "$(DESTDIR)$(bindir)"
	install -m 0755 $(BRANDING_SHORTNAME)-gtk "$(DESTDIR)$(bindir)"
	install -m 0755 deblibcver "$(DESTDIR)$(bindir)"


.PHONY: uninstall
uninstall:
#	$(BRANDING_SHORTNAME) --clean-cache
	rm -f $(DESTDIR)$(bindir)/$(BRANDING_SHORTNAME) $(DESTDIR)$(bindir)/$(BRANDING_SHORTNAME)-gtk
	rm -f $(DESTDIR)$(sharedir)/pixmaps/$(BRANDING_SHORTNAME).*
	rm -rf $(DESTDIR)$(sharedir)/pixmaps/$(BRANDING_SHORTNAME)
	rm -rf $(DESTDIR)$(libdir)/$(BRANDING_SHORTNAME)
#	rm -f $(DESTDIR)$(polkitdir)/$(BRANDING_SHORTNAME).policy
	rm -f $(DESTDIR)$(launcherdir)/$(BRANDING_SHORTNAME).desktop
	rm -f $(DESTDIR)$(localedir)/*/LC_MESSAGES/$(BRANDING_SHORTNAME).mo
	rm -f $(DESTDIR)/home/*/.config/$(BRANDING_SHORTNAME)/$(BRANDING_SHORTNAME)-notify.sh
	rm -f $(DESTDIR)/home/*/.config/autostart/$(BRANDING_SHORTNAME).desktop
	rm -f $(DESTDIR)$(bindir)/deblibcver


.PHONY: deb-src
deb-src: $(dsc_file)

$(dsc_file): debian/changelog $(misc_files) $(po_files)
	@[[ "$(pkg_version)" == "$(BRANDING_VERSION)" ]] || { echo -e "Version number in debian/changelog ($(pkg_version)) does not match BRANDING.mak ($(BRANDING_VERSION)).\n(Maybe need to run \"dch\"?)" >&2 ; exit 1 ; }
	$(MAKE) clean
	dpkg-source --build .
	mkdir -pv release/deb-src
	mv -fv ../$(BRANDING_SHORTNAME)_$(pkg_version).dsc release/deb-src/
	mv -fv ../$(BRANDING_SHORTNAME)_$(pkg_version).tar.* release/deb-src/
	ls -l release/deb-src

.PHONY: deb
deb: $(deb_file)

# To create the deb build env
#sudo apt intsall pbuilder-dist
#pbuilder-dist `lsb_release -sc` create
# To update the deb build env
#pbuilder-dist `lsb_release -sc` update
$(deb_file): $(dsc_file)
	mkdir -pv release/deb
	pbuilder-dist $(host_dist) build $(dsc_file) --buildresult release/deb
	mv -fv release/deb/$(BRANDING_SHORTNAME)_$(pkg_version)_$(host_arch).deb $(@)
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
	{ printf -v n "%04u" $$((10#$(DEB_BUILD_NUMBER)+1)) ; \
	[[ "_$(DEB_PKG_VERSION)" == "_$(pkg_version)" ]] || n="0000" ; \
	echo -e "# This file is generated by Makefile \"make $(@)\"\nDEB_PKG_VERSION := $(pkg_version)\nDEB_BUILD_NUMBER := $${n}" > .$(@).mak ; }

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
