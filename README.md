# Nixie Clock Desktop Gadget

<img width="850" height="476" alt="screenshot" src="https://github.com/user-attachments/assets/e85ff56a-48b9-48b8-b614-8f3dce2231a3" />

A lightweight, elegant desktop clock rendered with Cairo and GTK+3, designed to look like a vintage Nixie tube display floating directly on your desktop background.

---

## Features

* **3 Distinct Layout Styles**:
  * **Modern (Style 0)**: Sleek rounded glass with customizable neon glow and wire mesh.
  * **Authentic Real Tubes (Style 1)**: Faithful tribute to physical IN-14 tubes with stacked background cathode ghost digits (0–9) and warm amber glass.
  * **Cyberpunk VFD (Style 2)**: Futuristic electric cyan glow (`#00F2FF`), obsidian-black angular glass, and horizontal scanline matrix.
* **CPU Optimized**: Near 0.0% idle CPU usage when pulsing animations are disabled.
* **Interactive Controls**:
  * **Left-Click + Drag**: Move the clock anywhere on your screen.
  * **Right-Click**: Open the Preferences dialog or quit.
* **Customizable Settings**: Glow color, clock scale, window opacity, tube glass opacity, colon/digit pulse speeds, 12h (with AM/PM indicator tube) / 24h mode, and second visibility.
* **Persistent Configuration**: Automatically saves settings to `~/.config/nixie-clock/config.ini`.

---

## Dependencies

To build and run Nixie Clock from source, you need the following packages installed:

* **Vala Compiler** (`valac`)
* **GTK+ 3 development libraries** (`libgtk-3-dev`)
* **Cairo graphics library** (`libcairo2-dev`)

### Ubuntu / Debian / Linux Mint Installation
```bash
sudo apt update
sudo apt install valac libgtk-3-dev libcairo2-dev build-essential
```

---

## Building and Installation

Clone or download the project source, then use the provided Makefile:

```bash
# Compile the application
make

# Install system-wide
sudo make install

# Build a standalone .deb package
make deb
```

---

## Command-Line Options

You can launch the clock with custom parameters:

```bash
nixie-clock --layout 1 --scale 1.5 --use-12h --color "#FF3300"
```

Run `nixie-clock --help` for the full list of available command-line flags.

### ▷ [Changelog:](https://github.com/sofijacom/nixie-clock/blob/main/CHANGELOG.md)

- 1.1.1 option to hide the "tubes" background

- 1.1.2 added support for wayland bottom layer

- 1.3.0


## Author

_Mark Ulrich_ ► [forum.puppylinux](https://forum.puppylinux.com/viewtopic.php?t=17295)
