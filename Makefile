# Nixie Clock Widget
# Copyright (C) 2026
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

CC = valac
CFLAGS = --pkg gtk+-3.0 --pkg cairo --pkg gdk-3.0 --pkg pangocairo --Xcc=-lm
TARGET = nixie-clock
VERSION = 1.1.2
SRC = nixie_clock.vala
PREFIX ?= /usr

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(SRC) -o $(TARGET)

clean:
	rm -f $(TARGET)
	rm -rf deb_build
	rm -rf $(TARGET)-$(VERSION)
	rm -f $(TARGET)-$(VERSION).tar.gz
	rm -f *.deb

install: $(TARGET)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/$(TARGET)
	install -d $(DESTDIR)$(PREFIX)/share/applications
	echo "[Desktop Entry]" > $(DESTDIR)$(PREFIX)/share/applications/$(TARGET).desktop
	echo "Name=Nixie Clock" >> $(DESTDIR)$(PREFIX)/share/applications/$(TARGET).desktop
	echo "Comment=Sleek Desktop Nixie Tube Clock Widget" >> $(DESTDIR)$(PREFIX)/share/applications/$(TARGET).desktop
	echo "Exec=$(TARGET)" >> $(DESTDIR)$(PREFIX)/share/applications/$(TARGET).desktop
	echo "Icon=preferences-system-time" >> $(DESTDIR)$(PREFIX)/share/applications/$(TARGET).desktop
	echo "Terminal=false" >> $(DESTDIR)$(PREFIX)/share/applications/$(TARGET).desktop
	echo "Type=Application" >> $(DESTDIR)$(PREFIX)/share/applications/$(TARGET).desktop
	echo "Categories=Utility;Clock;GTK;" >> $(DESTDIR)$(PREFIX)/share/applications/$(TARGET).desktop

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(TARGET)
	rm -f $(DESTDIR)$(PREFIX)/share/applications/$(TARGET).desktop

deb: all
	rm -rf deb_build
	mkdir -p deb_build/DEBIAN
	mkdir -p deb_build/usr/bin
	mkdir -p deb_build/usr/share/applications
	install -m 755 $(TARGET) deb_build/usr/bin/
	echo "[Desktop Entry]" > deb_build/usr/share/applications/$(TARGET).desktop
	echo "Name=Nixie Clock" >> deb_build/usr/share/applications/$(TARGET).desktop
	echo "Comment=Sleek Desktop Nixie Tube Clock Widget" >> deb_build/usr/share/applications/$(TARGET).desktop
	echo "Exec=$(TARGET)" >> deb_build/usr/share/applications/$(TARGET).desktop
	echo "Icon=preferences-system-time" >> deb_build/usr/share/applications/$(TARGET).desktop
	echo "Terminal=false" >> deb_build/usr/share/applications/$(TARGET).desktop
	echo "Type=Application" >> deb_build/usr/share/applications/$(TARGET).desktop
	echo "Categories=Utility;Clock;GTK;" >> deb_build/usr/share/applications/$(TARGET).desktop
	echo "Package: $(TARGET)" > deb_build/DEBIAN/control
	echo "Version: $(VERSION)" >> deb_build/DEBIAN/control
	echo "Section: utils" >> deb_build/DEBIAN/control
	echo "Priority: optional" >> deb_build/DEBIAN/control
	echo "Architecture: amd64" >> deb_build/DEBIAN/control
	echo "Maintainer: Developer <dev@local>" >> deb_build/DEBIAN/control
	echo "Depends: libgtk-3-0, libcairo2, libpango-1.0-0, libpangocairo-1.0-0" >> deb_build/DEBIAN/control
	echo "Description: Sleek desktop Nixie tube clock widget written in Vala and GTK3" >> deb_build/DEBIAN/control
	dpkg-deb --build deb_build $(TARGET)_$(VERSION)_amd64.deb
	rm -rf deb_build

source:
	rm -rf $(TARGET)-$(VERSION)
	mkdir -p $(TARGET)-$(VERSION)
	cp $(SRC) Makefile README.md $(TARGET)-$(VERSION)/
	tar -czf $(TARGET)-$(VERSION).tar.gz $(TARGET)-$(VERSION)
	rm -rf $(TARGET)-$(VERSION)

dist: source

.PHONY: all clean install uninstall deb source dist
