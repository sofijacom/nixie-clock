## Changelog:

- 1.1.1 option to hide the "tubes" background

- 1.1.2 added support for wayland bottom layer

- 1.3.0 Changes:
  - reduced cpu-usage
  - compiled and Tested in Manjaro Plasma/Wayland
  - compiled and tested in Linux Mint/X11/Icewm
  - It uses a condition to check if it runs in wayland, then sets the class hint to UTILITY, while in X11 it uses DOCK. Also other Gtk and WM hints changed.
  - I found some settings not so logic so reworked them to be more "intuitive", and added more like glow-thickness.
