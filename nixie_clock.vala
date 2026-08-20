/*
 * Nixie Clock Widget (Optimized with Surface Caching)
 * Compile: valac --pkg gtk+-3.0 --pkg cairo --pkg gdk-3.0 --pkg pangocairo --Xcc=-lm nixie_clock.vala -o nixie-clock
 */

using Gtk;
using Cairo;
using GLib;
using Pango;
using Math;

public class NixieClockWindow : Gtk.Window {
    public static string[] saved_args;

    private Gtk.DrawingArea drawing_area;
    public int clock_style = 1;
    public bool use_24h = false;
    public bool show_seconds = true;
    public bool show_tube_background = true;
    public bool ampm_match_digit_style = false;
    public int window_type_hint_mode = 0; // 0: Auto, 1: Utility, 2: Dock

    // Position Tracking
    public int current_x = 0;
    public int current_y = 0;
    public OptionsDialog active_options_dialog = null;

    // Independent Colon Pulsing & Brightness
    public bool pulse_colon = true;
    public double colon_max_brightness = 1.0;
    public double colon_min_brightness = 0.2;
    public int colon_pulse_interval = 80;

    // Independent Number Pulsing & Brightness
    public bool pulse_numbers = true;
    public double number_max_brightness = 1.0;
    public double number_min_brightness = 0.6;
    public int number_pulse_interval = 120;

    // Mesh & Glow Controls
    public double border_brightness = 1.0;
    public double glow_thickness_digits = 1.0;
    public double glow_thickness_colons = 1.0;

    public int animation_mode = 1;
    public int am_pm_alignment = 0;
    public new double scale_factor = 1.0;
    public double tube_alpha = 0.95;

    // Animation Phases & Calculated Alpha Levels
    private double colon_phase = 0.0;
    private double number_phase = 0.0;
    public double current_colon_alpha = 1.0;
    public double current_number_alpha = 1.0;

    private uint colon_timer_id = 0;
    private uint number_timer_id = 0;
    private uint clock_timer_id = 0;
    private string last_drawn_time_str = "";

    // Bounding Box Rectangles for Partial Invalidation
    private Gdk.Rectangle colon1_rect = Gdk.Rectangle();
    private Gdk.Rectangle colon2_rect = Gdk.Rectangle();

    // Cached Pango Layouts
    private Pango.Layout digit_layout = null;
    private Pango.FontDescription digit_font_desc = null;
    private Pango.Layout ampm_layout = null;
    private Pango.FontDescription ampm_font_desc = null;

    // Surface Caching for Static Tube Backgrounds & Frames
    private Cairo.ImageSurface bg_cache_surface = null;
    private int cache_width = 0;
    private int cache_height = 0;
    private int cache_style = -1;
    private double cache_scale = -1.0;
    private bool cache_show_bg = true;
    private double cache_alpha = -1.0;
    private double cache_border_bright = -1.0;
    private bool cache_use_24h = false;
    private bool cache_show_seconds = true;
    private int cache_am_pm_alignment = -1;

    public struct TubeColor {
        public double r;
        public double g;
        public double b;
        public string name;
    }

    // Glow Color Settings
    public TubeColor custom_color = TubeColor() { r = 1.0, g = 0.5, b = 0.0, name = "Custom" };
    public TubeColor current_color = TubeColor() { r = 1.0, g = 0.33, b = 0.0, name = "Warm Amber" };

    public TubeColor[] color_presets = {
        TubeColor() { r = 1.0, g = 0.33, b = 0.0, name = "Warm Amber" },
        TubeColor() { r = 0.2, g = 0.85, b = 1.0, name = "Neon Cyan" },
        TubeColor() { r = 0.1, g = 1.0, b = 0.4, name = "Emerald Green" },
        TubeColor() { r = 0.6, g = 0.8, b = 1.0, name = "Ice Blue" },
        TubeColor() { r = 1.0, g = 0.2, b = 0.6, name = "Hot Magenta" }
    };

    // Digit Core Line Color Settings
    public TubeColor custom_digit_color = TubeColor() { r = 1.0, g = 0.95, b = 0.8, name = "Custom" };
    public TubeColor current_digit_color = TubeColor() { r = 1.0, g = 0.95, b = 0.8, name = "Warm White" };

    public TubeColor[] digit_color_presets = {
        TubeColor() { r = 1.0, g = 0.95, b = 0.8, name = "Warm White" },
        TubeColor() { r = 1.0, g = 1.0, b = 1.0, name = "Pure White" },
        TubeColor() { r = 1.0, g = 0.6, b = 0.0, name = "Vivid Amber" },
        TubeColor() { r = 0.4, g = 0.95, b = 1.0, name = "Electric Cyan" },
        TubeColor() { r = 0.3, g = 1.0, b = 0.5, name = "Neon Green" },
        TubeColor() { r = 1.0, g = 0.2, b = 0.2, name = "Crimson Red" }
    };

    public NixieClockWindow() {
        get_style_context().add_class("nixie-clock-window");
        apply_css();

        set_title("Nixie Clock");
        set_decorated(false);

        int saved_x = -1, saved_y = -1;
        bool has_saved_pos = load_config(out saved_x, out saved_y);

        apply_window_type_hint();

        set_keep_above(false);
        set_skip_taskbar_hint(true);
        set_skip_pager_hint(true);

        update_window_geometry();

        if (has_saved_pos && (saved_x != -1 || saved_y != -1)) {
            apply_window_position(saved_x, saved_y);
        } else {
            set_position(Gtk.WindowPosition.CENTER);
        }

        this.configure_event.connect((event) => {
            if (event.x != 0 || event.y != 0) {
                current_x = (int)event.x;
                current_y = (int)event.y;
            }

            if (active_options_dialog != null) {
                active_options_dialog.update_position_spins(current_x, current_y);
            }
            return false;
        });

        set_app_paintable(true);

        var visual = get_screen().get_rgba_visual();
        if (visual != null) {
            set_visual(visual);
        }

        stick();

        drawing_area = new Gtk.DrawingArea();
        drawing_area.set_app_paintable(true);
        add(drawing_area);

        drawing_area.draw.connect(on_draw);
        drawing_area.set_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.POINTER_MOTION_MASK);
        drawing_area.button_press_event.connect(on_button_press);

        start_timers();
    }

    public void apply_window_type_hint() {
        if (window_type_hint_mode == 1) {
            this.set_type_hint(Gdk.WindowTypeHint.UTILITY);
        } else if (window_type_hint_mode == 2) {
            this.set_type_hint(Gdk.WindowTypeHint.DOCK);
        } else {
            bool is_wayland = (Environment.get_variable("WAYLAND_DISPLAY") != null);
            if (is_wayland) {
                this.set_type_hint(Gdk.WindowTypeHint.UTILITY);
            } else {
                this.set_type_hint(Gdk.WindowTypeHint.DOCK);
            }
        }
    }

    public void invalidate_bg_cache() {
        bg_cache_surface = null;
    }

    private void apply_css() {
        var provider = new Gtk.CssProvider();
        try {
            provider.load_from_data("""
            window.nixie-clock-window,
            window.nixie-clock-window.background,
            window.nixie-clock-window decoration {
            background-color: transparent;
            background-image: none;
            box-shadow: none;
            border: none;
            margin: 0;
            padding: 0;
            outline: none;
        }
        """);
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                                                     provider,
                                                     Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            stderr.printf("[ERROR] Failed to load CSS: %s\n", e.message);
        }
    }

    public void apply_window_position(int x, int y) {
        current_x = x;
        current_y = y;
        move(x, y);
        queue_draw();
    }

    public void get_current_position(out int x, out int y) {
        get_position(out x, out y);
        if (x == 0 && y == 0 && (current_x != 0 || current_y != 0)) {
            x = current_x;
            y = current_y;
        }
    }

    private string get_config_path() {
        return GLib.Path.build_filename(Environment.get_user_config_dir(), "nixie_clock", "config.ini");
    }

    public bool load_config(out int out_x, out int out_y) {
        out_x = -1;
        out_y = -1;
        var path = get_config_path();
        var kf = new KeyFile();
        try {
            if (kf.load_from_file(path, KeyFileFlags.NONE)) {
                if (kf.has_key("Settings", "clock_style")) clock_style = kf.get_integer("Settings", "clock_style");
                if (kf.has_key("Settings", "use_24h")) use_24h = kf.get_boolean("Settings", "use_24h");
                if (kf.has_key("Settings", "show_seconds")) show_seconds = kf.get_boolean("Settings", "show_seconds");
                if (kf.has_key("Settings", "show_tube_background")) show_tube_background = kf.get_boolean("Settings", "show_tube_background");
                if (kf.has_key("Settings", "ampm_match_digit_style")) ampm_match_digit_style = kf.get_boolean("Settings", "ampm_match_digit_style");
                if (kf.has_key("Settings", "window_type_hint_mode")) window_type_hint_mode = kf.get_integer("Settings", "window_type_hint_mode");

                if (kf.has_key("Settings", "pulse_colon")) pulse_colon = kf.get_boolean("Settings", "pulse_colon");
                if (kf.has_key("Settings", "colon_max_brightness")) colon_max_brightness = kf.get_double("Settings", "colon_max_brightness");
                if (kf.has_key("Settings", "colon_min_brightness")) colon_min_brightness = kf.get_double("Settings", "colon_min_brightness");
                if (kf.has_key("Settings", "colon_pulse_interval")) colon_pulse_interval = kf.get_integer("Settings", "colon_pulse_interval");

                if (kf.has_key("Settings", "pulse_numbers")) pulse_numbers = kf.get_boolean("Settings", "pulse_numbers");
                if (kf.has_key("Settings", "number_max_brightness")) number_max_brightness = kf.get_double("Settings", "number_max_brightness");
                if (kf.has_key("Settings", "number_min_brightness")) number_min_brightness = kf.get_double("Settings", "number_min_brightness");
                if (kf.has_key("Settings", "number_pulse_interval")) number_pulse_interval = kf.get_integer("Settings", "number_pulse_interval");

                if (kf.has_key("Settings", "border_brightness")) border_brightness = kf.get_double("Settings", "border_brightness");

                if (kf.has_key("Settings", "glow_thickness_digits")) {
                    glow_thickness_digits = kf.get_double("Settings", "glow_thickness_digits");
                } else if (kf.has_key("Settings", "glow_thickness")) {
                    glow_thickness_digits = kf.get_double("Settings", "glow_thickness");
                }

                if (kf.has_key("Settings", "glow_thickness_colons")) {
                    glow_thickness_colons = kf.get_double("Settings", "glow_thickness_colons");
                } else if (kf.has_key("Settings", "glow_thickness")) {
                    glow_thickness_colons = kf.get_double("Settings", "glow_thickness");
                }

                if (kf.has_key("Settings", "animation_mode")) animation_mode = kf.get_integer("Settings", "animation_mode");
                if (kf.has_key("Settings", "am_pm_alignment")) am_pm_alignment = kf.get_integer("Settings", "am_pm_alignment");
                if (kf.has_key("Settings", "scale_factor")) scale_factor = kf.get_double("Settings", "scale_factor");
                if (kf.has_key("Settings", "tube_alpha")) tube_alpha = kf.get_double("Settings", "tube_alpha");

                // Glow Color
                if (kf.has_key("Settings", "custom_r")) custom_color.r = kf.get_double("Settings", "custom_r");
                if (kf.has_key("Settings", "custom_g")) custom_color.g = kf.get_double("Settings", "custom_g");
                if (kf.has_key("Settings", "custom_b")) custom_color.b = kf.get_double("Settings", "custom_b");

                if (kf.has_key("Settings", "glow_color")) {
                    string color_name = kf.get_string("Settings", "glow_color");
                    if (color_name == "Custom") {
                        current_color = custom_color;
                    } else {
                        foreach (var preset in color_presets) {
                            if (preset.name == color_name) {
                                current_color = preset;
                                break;
                            }
                        }
                    }
                }

                // Digit Line Color
                if (kf.has_key("Settings", "custom_digit_r")) custom_digit_color.r = kf.get_double("Settings", "custom_digit_r");
                if (kf.has_key("Settings", "custom_digit_g")) custom_digit_color.g = kf.get_double("Settings", "custom_digit_g");
                if (kf.has_key("Settings", "custom_digit_b")) custom_digit_color.b = kf.get_double("Settings", "custom_digit_b");

                if (kf.has_key("Settings", "digit_line_color")) {
                    string dcolor_name = kf.get_string("Settings", "digit_line_color");
                    if (dcolor_name == "Custom") {
                        current_digit_color = custom_digit_color;
                    } else {
                        foreach (var preset in digit_color_presets) {
                            if (preset.name == dcolor_name) {
                                current_digit_color = preset;
                                break;
                            }
                        }
                    }
                }

                if (kf.has_key("Settings", "window_x") && kf.has_key("Settings", "window_y")) {
                    out_x = kf.get_integer("Settings", "window_x");
                    out_y = kf.get_integer("Settings", "window_y");
                    current_x = out_x;
                    current_y = out_y;
                    return true;
                }
            }
        } catch (Error e) {
            // Ignore missing file on initial launch
        }
        return false;
    }

    public void save_config() {
        var path = get_config_path();
        var dir = GLib.Path.get_dirname(path);
        try {
            DirUtils.create_with_parents(dir, 0755);
            var kf = new KeyFile();
            kf.set_integer("Settings", "clock_style", clock_style);
            kf.set_boolean("Settings", "use_24h", use_24h);
            kf.set_boolean("Settings", "show_seconds", show_seconds);
            kf.set_boolean("Settings", "show_tube_background", show_tube_background);
            kf.set_boolean("Settings", "ampm_match_digit_style", ampm_match_digit_style);
            kf.set_integer("Settings", "window_type_hint_mode", window_type_hint_mode);

            kf.set_boolean("Settings", "pulse_colon", pulse_colon);
            kf.set_double("Settings", "colon_max_brightness", colon_max_brightness);
            kf.set_double("Settings", "colon_min_brightness", colon_min_brightness);
            kf.set_integer("Settings", "colon_pulse_interval", colon_pulse_interval);

            kf.set_boolean("Settings", "pulse_numbers", pulse_numbers);
            kf.set_double("Settings", "number_max_brightness", number_max_brightness);
            kf.set_double("Settings", "number_min_brightness", number_min_brightness);
            kf.set_integer("Settings", "number_pulse_interval", number_pulse_interval);

            kf.set_double("Settings", "border_brightness", border_brightness);
            kf.set_double("Settings", "glow_thickness_digits", glow_thickness_digits);
            kf.set_double("Settings", "glow_thickness_colons", glow_thickness_colons);
            kf.set_integer("Settings", "animation_mode", animation_mode);
            kf.set_integer("Settings", "am_pm_alignment", am_pm_alignment);
            kf.set_double("Settings", "scale_factor", scale_factor);
            kf.set_double("Settings", "tube_alpha", tube_alpha);

            // Glow Color
            kf.set_double("Settings", "custom_r", custom_color.r);
            kf.set_double("Settings", "custom_g", custom_color.g);
            kf.set_double("Settings", "custom_b", custom_color.b);
            kf.set_string("Settings", "glow_color", current_color.name);

            // Digit Line Color
            kf.set_double("Settings", "custom_digit_r", custom_digit_color.r);
            kf.set_double("Settings", "custom_digit_g", custom_digit_color.g);
            kf.set_double("Settings", "custom_digit_b", custom_digit_color.b);
            kf.set_string("Settings", "digit_line_color", current_digit_color.name);

            int wx, wy;
            get_current_position(out wx, out wy);
            kf.set_integer("Settings", "window_x", wx);
            kf.set_integer("Settings", "window_y", wy);

            string data = kf.to_data(null);
            FileUtils.set_contents(path, data);
        } catch (Error e) {
            stderr.printf("[ERROR] Failed to save configuration: %s\n", e.message);
        }
    }

    private void update_pango_fonts() {
        int font_size = (int)(62 * scale_factor);
        digit_font_desc = Pango.FontDescription.from_string("Sans Bold %d".printf(font_size));
        if (digit_layout != null) {
            digit_layout.set_font_description(digit_font_desc);
        }

        int ampm_font_size = (int)(18 * scale_factor);
        ampm_font_desc = Pango.FontDescription.from_string("Sans Bold %d".printf(ampm_font_size));
        if (ampm_layout != null) {
            ampm_layout.set_font_description(ampm_font_desc);
        }
    }

    public void update_window_geometry() {
        int base_w = show_seconds ? (use_24h ? 520 : 600) : (use_24h ? 340 : 420);
        int base_h = 160;
        set_default_size((int)(base_w * scale_factor), (int)(base_h * scale_factor));
        resize((int)(base_w * scale_factor), (int)(base_h * scale_factor));
        update_pango_fonts();
        invalidate_bg_cache();
    }

    private void ensure_pango_layouts(Cairo.Context cr) {
        if (digit_layout == null) {
            digit_layout = Pango.cairo_create_layout(cr);
            ampm_layout = Pango.cairo_create_layout(cr);
            update_pango_fonts();
        }
    }

    public void start_timers() {
        if (colon_timer_id != 0) Source.remove(colon_timer_id);
        if (number_timer_id != 0) Source.remove(number_timer_id);
        if (clock_timer_id != 0) Source.remove(clock_timer_id);

        colon_timer_id = 0;
        number_timer_id = 0;
        clock_timer_id = 0;

        current_colon_alpha = colon_max_brightness;
        current_number_alpha = number_max_brightness;

        // Clock Update Timer
        uint interval = show_seconds ? 1000 : 2000;
        clock_timer_id = GLib.Timeout.add(interval, () => {
            var now = new DateTime.now_local();
            int h = now.get_hour();
            if (!use_24h) {
                h = h % 12;
                if (h == 0) h = 12;
            }
            string current_time_str = show_seconds ?
            "%02d:%02d:%02d".printf(h, now.get_minute(), now.get_second()) :
            "%02d:%02d".printf(h, now.get_minute());

            if (current_time_str != last_drawn_time_str) {
                drawing_area.queue_draw();
            }
            return true;
        });

        // Colon Animation Timer
        if (pulse_colon && animation_mode != 2) {
            int interval_ms = int.max(20, colon_pulse_interval);
            colon_timer_id = GLib.Timeout.add(interval_ms, () => {
                colon_phase += 0.15;
                if (colon_phase >= Math.PI * 2.0) colon_phase -= Math.PI * 2.0;

                double wave = (Math.sin(colon_phase) + 1.0) / 2.0;
                current_colon_alpha = colon_min_brightness + (colon_max_brightness - colon_min_brightness) * wave;

                if (colon1_rect.width > 0 && colon1_rect.height > 0) {
                    drawing_area.queue_draw_area(colon1_rect.x, colon1_rect.y, colon1_rect.width, colon1_rect.height);
                }
                if (show_seconds && colon2_rect.width > 0 && colon2_rect.height > 0) {
                    drawing_area.queue_draw_area(colon2_rect.x, colon2_rect.y, colon2_rect.width, colon2_rect.height);
                }
                return true;
            });
        }

        // Digit Animation Timer
        if (pulse_numbers && animation_mode != 2) {
            int interval_ms = int.max(20, number_pulse_interval);
            number_timer_id = GLib.Timeout.add(interval_ms, () => {
                number_phase += 0.15;
                if (number_phase >= Math.PI * 2.0) number_phase -= Math.PI * 2.0;

                double wave = (Math.sin(number_phase) + 1.0) / 2.0;
                current_number_alpha = number_min_brightness + (number_max_brightness - number_min_brightness) * wave;

                drawing_area.queue_draw();
                return true;
            });
        }
    }

    public void restart_timers() {
        start_timers();
    }

    public void queue_redraw() {
        invalidate_bg_cache();
        drawing_area.queue_draw();
    }

    private bool on_button_press(Gdk.EventButton event) {
        if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == 1) {
            this.begin_move_drag(
                (int) event.button,
                                 (int) event.x_root,
                                 (int) event.y_root,
                                 event.time
            );
            return true;
        } else if (event.button == 3) {
            show_context_menu(event);
            return true;
        }
        return false;
    }

    private void show_context_menu(Gdk.EventButton event) {
        var menu = new Gtk.Menu();

        var item_options = new Gtk.MenuItem.with_label("Options...");
        item_options.activate.connect(() => {
            if (active_options_dialog == null) {
                active_options_dialog = new OptionsDialog(this);
                active_options_dialog.destroy.connect(() => {
                    active_options_dialog = null;
                });
                active_options_dialog.show();
            } else {
                active_options_dialog.present();
            }
        });
        menu.append(item_options);

        menu.append(new Gtk.SeparatorMenuItem());

        var item_quit = new Gtk.MenuItem.with_label("Quit");
        item_quit.activate.connect(() => {
            save_config();
            Gtk.main_quit();
        });
        menu.append(item_quit);

        menu.show_all();
        menu.popup_at_pointer((Gdk.Event?)event);
    }

    private void refresh_bg_cache(double w, double h, double start_x, double start_y, double tube_w, double tube_h, double spacing, double colon_w, double am_w, int num_tubes) {
        bg_cache_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, (int)w, (int)h);
        var surface_cr = new Cairo.Context(bg_cache_surface);

        double cur_x = start_x;

        // Draw Hour 1 & 2 Background Frames
        draw_tube_background_and_frame(surface_cr, cur_x, start_y, tube_w, tube_h);
        cur_x += tube_w + spacing;
        draw_tube_background_and_frame(surface_cr, cur_x, start_y, tube_w, tube_h);
        cur_x += tube_w + spacing;

        // Colon 1 spacing
        cur_x += colon_w + spacing;

        // Minute 1 & 2 Background Frames
        draw_tube_background_and_frame(surface_cr, cur_x, start_y, tube_w, tube_h);
        cur_x += tube_w + spacing;
        draw_tube_background_and_frame(surface_cr, cur_x, start_y, tube_w, tube_h);
        cur_x += tube_w + spacing;

        if (show_seconds) {
            // Colon 2 spacing
            cur_x += colon_w + spacing;

            // Second 1 & 2 Background Frames
            draw_tube_background_and_frame(surface_cr, cur_x, start_y, tube_w, tube_h);
            cur_x += tube_w + spacing;
            draw_tube_background_and_frame(surface_cr, cur_x, start_y, tube_w, tube_h);
            cur_x += tube_w + spacing;
        }

        if (!use_24h) {
            double am_h = tube_h * 0.5;
            double am_y;
            if (am_pm_alignment == 0) {
                am_y = start_y;
            } else if (am_pm_alignment == 2) {
                am_y = start_y + tube_h - am_h;
            } else {
                am_y = start_y + (tube_h - am_h) / 2.0;
            }
            draw_tube_background_and_frame(surface_cr, cur_x, am_y, am_w, am_h);
        }

        cache_width = (int)w;
        cache_height = (int)h;
        cache_style = clock_style;
        cache_scale = scale_factor;
        cache_show_bg = show_tube_background;
        cache_alpha = tube_alpha;
        cache_border_bright = border_brightness;
        cache_use_24h = use_24h;
        cache_show_seconds = show_seconds;
        cache_am_pm_alignment = am_pm_alignment;
    }

    private bool on_draw(Cairo.Context cr) {
        ensure_pango_layouts(cr);

        Gtk.Allocation alloc;
        get_allocation(out alloc);
        double w = alloc.width;
        double h = alloc.height;

        cr.set_source_rgba(0.0, 0.0, 0.0, 0.0);
        cr.set_operator(Cairo.Operator.SOURCE);
        cr.paint();
        cr.set_operator(Cairo.Operator.OVER);

        var now = new DateTime.now_local();
        int hour = now.get_hour();
        bool is_pm = hour >= 12;

        if (!use_24h) {
            hour = hour % 12;
            if (hour == 0) hour = 12;
        }

        int minute = now.get_minute();
        int second = now.get_second();

        last_drawn_time_str = show_seconds ?
        "%02d:%02d:%02d".printf(hour, minute, second) :
        "%02d:%02d".printf(hour, minute);

        int num_tubes = show_seconds ? 6 : 4;
        double tube_w = 58.0 * scale_factor;
        double tube_h = 120.0 * scale_factor;
        double spacing = 8.0 * scale_factor;
        double colon_w = 18.0 * scale_factor;
        double am_w = tube_w * 0.75;

        double total_w = (num_tubes * tube_w) + (show_seconds ? (2 * colon_w) : colon_w) + ((num_tubes + (show_seconds ? 1 : 0)) * spacing);
        if (!use_24h) {
            total_w += spacing + am_w;
        }

        double start_x = (w - total_w) / 2.0;
        if (start_x < 5.0) start_x = 5.0;
        double start_y = (h - tube_h) / 2.0;

        // Check if background cache needs to be generated or refreshed
        bool cache_valid = (bg_cache_surface != null &&
        cache_width == (int)w &&
        cache_height == (int)h &&
        cache_style == clock_style &&
        cache_scale == scale_factor &&
        cache_show_bg == show_tube_background &&
        cache_alpha == tube_alpha &&
        cache_border_bright == border_brightness &&
        cache_use_24h == use_24h &&
        cache_show_seconds == show_seconds &&
        cache_am_pm_alignment == am_pm_alignment);

        if (!cache_valid) {
            refresh_bg_cache(w, h, start_x, start_y, tube_w, tube_h, spacing, colon_w, am_w, num_tubes);
        }

        // Blit pre-rendered static background cache in one fast operation
        if (bg_cache_surface != null) {
            cr.set_source_surface(bg_cache_surface, 0, 0);
            cr.paint();
        }

        // Render dynamic digits and colons on top
        double cur_x = start_x;

        draw_digit_glow(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(hour)[0].to_string());
        cur_x += tube_w + spacing;
        draw_digit_glow(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(hour)[1].to_string());
        cur_x += tube_w + spacing;

        colon1_rect = Gdk.Rectangle() { x = (int)cur_x, y = (int)start_y, width = (int)colon_w, height = (int)tube_h };
        draw_colon(cr, cur_x, start_y, colon_w, tube_h, current_colon_alpha);
        cur_x += colon_w + spacing;

        draw_digit_glow(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(minute)[0].to_string());
        cur_x += tube_w + spacing;
        draw_digit_glow(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(minute)[1].to_string());
        cur_x += tube_w + spacing;

        if (show_seconds) {
            colon2_rect = Gdk.Rectangle() { x = (int)cur_x, y = (int)start_y, width = (int)colon_w, height = (int)tube_h };
            draw_colon(cr, cur_x, start_y, colon_w, tube_h, current_colon_alpha);
            cur_x += colon_w + spacing;

            draw_digit_glow(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(second)[0].to_string());
            cur_x += tube_w + spacing;
            draw_digit_glow(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(second)[1].to_string());
            cur_x += tube_w + spacing;
        }

        if (!use_24h) {
            double am_h = tube_h * 0.5;
            double am_y;
            if (am_pm_alignment == 0) {
                am_y = start_y;
            } else if (am_pm_alignment == 2) {
                am_y = start_y + tube_h - am_h;
            } else {
                am_y = start_y + (tube_h - am_h) / 2.0;
            }
            draw_am_pm_glow(cr, cur_x, am_y, am_w, am_h, is_pm);
        }

        return false;
    }

    private void draw_tube_background(Cairo.Context cr, double x, double y, double w, double h) {
        if (!show_tube_background) return;

        if (clock_style == 1) {
            var pat = new Cairo.Pattern.linear(x, y, x + w, y + h);
            pat.add_color_stop_rgba(0.0, 0.15, 0.12, 0.10, tube_alpha);
            pat.add_color_stop_rgba(0.5, 0.05, 0.04, 0.03, tube_alpha);
            pat.add_color_stop_rgba(1.0, 0.12, 0.08, 0.05, tube_alpha);
            cr.set_source(pat);
        } else if (clock_style == 4) {
            var pat = new Cairo.Pattern.radial(
                x + w * 0.35, y + h * 0.35, 5.0 * scale_factor,
                x + w * 0.5,  y + h * 0.5,  w * 0.75
            );
            pat.add_color_stop_rgba(0.0, 0.14, 0.42, 0.58, tube_alpha);
            pat.add_color_stop_rgba(0.45, 0.05, 0.22, 0.38, tube_alpha);
            pat.add_color_stop_rgba(1.0, 0.01, 0.08, 0.18, tube_alpha);
            cr.set_source(pat);
        } else if (clock_style == 3) {
            var pat = new Cairo.Pattern.linear(x, y, x, y + h);
            pat.add_color_stop_rgba(0.0, 0.05, 0.18, 0.35, tube_alpha * 0.9);
            pat.add_color_stop_rgba(0.5, 0.02, 0.08, 0.18, tube_alpha);
            pat.add_color_stop_rgba(1.0, 0.01, 0.04, 0.10, tube_alpha * 0.95);
            cr.set_source(pat);
        } else if (clock_style == 2) {
            cr.set_source_rgba(0.02, 0.02, 0.05, tube_alpha);
        } else {
            var pat = new Cairo.Pattern.linear(x, y, x, y + h);
            pat.add_color_stop_rgba(0.0, 0.08, 0.09, 0.12, tube_alpha * 0.85);
            pat.add_color_stop_rgba(1.0, 0.03, 0.04, 0.06, tube_alpha * 0.95);
            cr.set_source(pat);
        }

        double radius = (clock_style >= 1) ? (10.0 * scale_factor) : (6.0 * scale_factor);
        rounded_rectangle(cr, x, y, w, h, radius);
        cr.fill_preserve();
    }

    private void draw_tube_background_and_frame(Cairo.Context cr, double x, double y, double w, double h) {
        if (!show_tube_background) return;

        draw_tube_background(cr, x, y, w, h);

        if (clock_style == 1) {
            cr.set_source_rgba(0.4, 0.3, 0.2, 0.8 * border_brightness);
            cr.set_line_width(1.5 * scale_factor);
            cr.stroke();

            if (border_brightness > 0.01) {
                cr.set_source_rgba(0.3, 0.2, 0.1, 0.25 * border_brightness);
                cr.set_line_width(0.5 * scale_factor);
                double grid_step = 6.0 * scale_factor;
                cr.new_path();
                for (double gx = x + (4.0 * scale_factor); gx < x + w - (4.0 * scale_factor); gx += grid_step) {
                    cr.move_to(gx, y + (6.0 * scale_factor));
                    cr.line_to(gx, y + h - (6.0 * scale_factor));
                }
                for (double gy = y + (6.0 * scale_factor); gy < y + h - (6.0 * scale_factor); gy += grid_step) {
                    cr.move_to(x + (4.0 * scale_factor), gy);
                    cr.line_to(x + w - (4.0 * scale_factor), gy);
                }
                cr.stroke();
            }
        } else {
            if (clock_style == 2 || clock_style == 4) {
                cr.set_source_rgba(current_color.r * 0.9, current_color.g * 0.9, current_color.b * 0.9, 0.95 * border_brightness);
            } else if (clock_style == 3) {
                cr.set_source_rgba(current_color.r * 0.85, current_color.g * 0.85, current_color.b * 0.85, 0.9 * border_brightness);
            } else {
                cr.set_source_rgba(0.25, 0.65, 0.85, 0.85 * border_brightness);
            }
            cr.set_line_width(((clock_style == 2 || clock_style == 4) ? 2.0 : 1.5) * scale_factor);
            cr.stroke();

            if ((clock_style == 2 || clock_style == 4) && border_brightness > 0.01) {
                cr.set_source_rgba(current_color.r, current_color.g, current_color.b, ((clock_style == 4) ? 0.14 : 0.15) * border_brightness);
                cr.set_line_width(0.5 * scale_factor);
                double step = (clock_style == 4) ? (4.5 * scale_factor) : (10.0 * scale_factor);
                cr.new_path();
                for (double i = y + (8 * scale_factor); i < y + h - (8 * scale_factor); i += step) {
                    cr.move_to(x + (3.0 * scale_factor), i);
                    cr.line_to(x + w - (3.0 * scale_factor), i);
                }
                cr.stroke();
            }
        }
    }

    private void draw_digit_glow(Cairo.Context cr, double x, double y, double w, double h, string digit_str) {
        cr.save();
        digit_layout.set_text(digit_str, -1);

        Pango.Rectangle ink_rect, logical_rect;
        digit_layout.get_extents(out ink_rect, out logical_rect);

        double text_w = logical_rect.width / Pango.SCALE;
        double text_h = logical_rect.height / Pango.SCALE;

        double text_x = x + (w - text_w) / 2.0;
        double text_y = y + (h - text_h) / 2.0;

        cr.move_to(text_x, text_y);
        Pango.cairo_layout_path(cr, digit_layout);

        double alpha_mod = current_number_alpha;
        double gt = glow_thickness_digits;

        if (clock_style == 1) {
            cr.set_source_rgba(current_color.r, current_color.g * 0.4, current_color.b * 0.1, 0.15 * alpha_mod);
            cr.set_line_width(12.0 * scale_factor * gt);
            cr.stroke_preserve();

            cr.set_source_rgba(current_color.r, current_color.g * 0.5, current_color.b * 0.1, 0.3 * alpha_mod);
            cr.set_line_width(6.0 * scale_factor * gt);
            cr.stroke_preserve();

            cr.set_source_rgba(current_color.r, current_color.g * 0.8, current_color.b * 0.2, 0.8 * alpha_mod);
            cr.set_line_width(2.5 * scale_factor * gt);
            cr.stroke_preserve();

            cr.set_source_rgba(current_digit_color.r, current_digit_color.g, current_digit_color.b, alpha_mod);
            cr.set_line_width(1.0 * scale_factor);
            cr.stroke();
        } else if (clock_style > 1) {
            cr.set_source_rgba(current_color.r * 0.9, current_color.g * 0.8, current_color.b, 0.14 * alpha_mod);
            cr.set_line_width(11.0 * scale_factor * gt);
            cr.stroke_preserve();

            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.32 * alpha_mod);
            cr.set_line_width(5.5 * scale_factor * gt);
            cr.stroke_preserve();

            cr.set_source_rgba(Math.fmin(1.0, current_color.r * 1.1), Math.fmin(1.0, current_color.g * 1.1), Math.fmin(1.0, current_color.b * 1.1), 0.88 * alpha_mod);
            cr.set_line_width(2.0 * scale_factor * gt);
            cr.stroke_preserve();

            cr.set_source_rgba(current_digit_color.r, current_digit_color.g, current_digit_color.b, alpha_mod);
            cr.set_line_width(0.7 * scale_factor);
            cr.stroke();
        } else {
            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.22 * alpha_mod);
            cr.set_line_width(6.0 * scale_factor * gt);
            cr.stroke_preserve();

            cr.set_source_rgba(current_digit_color.r, current_digit_color.g, current_digit_color.b, 0.92 * alpha_mod);
            cr.set_line_width(1.8 * scale_factor);
            cr.stroke();
        }

        cr.restore();
    }

    private void draw_single_colon_dot(Cairo.Context cr, double cx, double cy, double r, double alpha_mod) {
        cr.save();
        double gt = glow_thickness_colons;

        if (clock_style == 1) {
            cr.arc(cx, cy, r * 2.8 * gt, 0, 2.0 * Math.PI);
            cr.set_source_rgba(current_color.r, current_color.g * 0.4, current_color.b * 0.1, 0.15 * alpha_mod);
            cr.fill();

            cr.arc(cx, cy, r * 2.0 * gt, 0, 2.0 * Math.PI);
            cr.set_source_rgba(current_color.r, current_color.g * 0.5, current_color.b * 0.1, 0.3 * alpha_mod);
            cr.fill();

            cr.arc(cx, cy, r * 1.4 * gt, 0, 2.0 * Math.PI);
            cr.set_source_rgba(current_color.r, current_color.g * 0.8, current_color.b * 0.2, 0.8 * alpha_mod);
            cr.fill();

            cr.arc(cx, cy, r * 0.8, 0, 2.0 * Math.PI);
            cr.set_source_rgba(current_digit_color.r, current_digit_color.g, current_digit_color.b, alpha_mod);
            cr.fill();
        } else if (clock_style > 1) {
            cr.arc(cx, cy, r * 2.6 * gt, 0, 2.0 * Math.PI);
            cr.set_source_rgba(current_color.r * 0.9, current_color.g * 0.8, current_color.b, 0.14 * alpha_mod);
            cr.fill();

            cr.arc(cx, cy, r * 1.8 * gt, 0, 2.0 * Math.PI);
            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.32 * alpha_mod);
            cr.fill();

            cr.arc(cx, cy, r * 1.3 * gt, 0, 2.0 * Math.PI);
            cr.set_source_rgba(Math.fmin(1.0, current_color.r * 1.1), Math.fmin(1.0, current_color.g * 1.1), Math.fmin(1.0, current_color.b * 1.1), 0.88 * alpha_mod);
            cr.fill();

            cr.arc(cx, cy, r * 0.8, 0, 2.0 * Math.PI);
            cr.set_source_rgba(current_digit_color.r, current_digit_color.g, current_digit_color.b, alpha_mod);
            cr.fill();
        } else {
            cr.arc(cx, cy, r * 1.8 * gt, 0, 2.0 * Math.PI);
            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.22 * alpha_mod);
            cr.fill();

            cr.arc(cx, cy, r * 0.8, 0, 2.0 * Math.PI);
            cr.set_source_rgba(current_digit_color.r, current_digit_color.g, current_digit_color.b, 0.92 * alpha_mod);
            cr.fill();
        }

        cr.restore();
    }

    private void draw_colon(Cairo.Context cr, double x, double y, double w, double h, double alpha) {
        double cx = x + w / 2.0;
        double dot_r = 3.8 * scale_factor;
        double y1 = y + h * 0.35;
        double y2 = y + h * 0.65;

        draw_single_colon_dot(cr, cx, y1, dot_r, alpha);
        draw_single_colon_dot(cr, cx, y2, dot_r, alpha);
    }

    private void draw_am_pm_glow(Cairo.Context cr, double x, double y, double w, double h, bool is_pm) {
        cr.save();
        ampm_layout.set_text(is_pm ? "pm" : "am", -1);

        Pango.Rectangle ink_rect, logical_rect;
        ampm_layout.get_extents(out ink_rect, out logical_rect);

        double text_w = logical_rect.width / Pango.SCALE;
        double text_h = logical_rect.height / Pango.SCALE;

        double text_x = x + (w - text_w) / 2.0;
        double text_y = y + (h - text_h) / 2.0;

        cr.move_to(text_x, text_y);
        Pango.cairo_layout_path(cr, ampm_layout);

        double alpha_mod = current_number_alpha;

        if (ampm_match_digit_style) {
            double am_scale = 0.35 * scale_factor * glow_thickness_digits;

            if (clock_style == 1) {
                cr.set_source_rgba(current_color.r, current_color.g * 0.4, current_color.b * 0.1, 0.15 * alpha_mod);
                cr.set_line_width(12.0 * am_scale);
                cr.stroke_preserve();

                cr.set_source_rgba(current_color.r, current_color.g * 0.5, current_color.b * 0.1, 0.3 * am_scale);
                cr.set_line_width(6.0 * am_scale);
                cr.stroke_preserve();

                cr.set_source_rgba(current_color.r, current_color.g * 0.8, current_color.b * 0.2, 0.8 * alpha_mod);
                cr.set_line_width(2.5 * am_scale);
                cr.stroke_preserve();

                cr.set_source_rgba(current_digit_color.r, current_digit_color.g, current_digit_color.b, alpha_mod);
                cr.set_line_width(0.7 * scale_factor);
                cr.stroke();
            } else {
                cr.set_source_rgba(current_color.r * 0.9, current_color.g * 0.8, current_color.b, 0.14 * alpha_mod);
                cr.set_line_width(11.0 * am_scale);
                cr.stroke_preserve();

                cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.32 * alpha_mod);
                cr.set_line_width(5.5 * am_scale);
                cr.stroke_preserve();

                cr.set_source_rgba(Math.fmin(1.0, current_color.r * 1.1), Math.fmin(1.0, current_color.g * 1.1), Math.fmin(1.0, current_color.b * 1.1), 0.88 * alpha_mod);
                cr.set_line_width(2.0 * am_scale);
                cr.stroke_preserve();

                cr.set_source_rgba(current_digit_color.r, current_digit_color.g, current_digit_color.b, alpha_mod);
                cr.set_line_width(0.6 * scale_factor);
                cr.stroke();
            }
        } else {
            cr.set_source_rgba(current_digit_color.r, current_digit_color.g, current_digit_color.b, 0.92 * alpha_mod);
            cr.set_line_width(1.1 * scale_factor);
            cr.stroke();
        }

        cr.restore();
    }

    private void rounded_rectangle(Cairo.Context cr, double x, double y, double w, double h, double r) {
        cr.new_path();
        cr.arc(x + w - r, y + r, r, -Math.PI / 2.0, 0.0);
        cr.arc(x + w - r, y + h - r, r, 0.0, Math.PI / 2.0);
        cr.arc(x + r, y + h - r, r, Math.PI / 2.0, Math.PI);
        cr.arc(x + r, y + r, r, Math.PI, 3.0 * Math.PI / 2.0);
        cr.close_path();
    }
}

public class OptionsDialog : Gtk.Dialog {
    public NixieClockWindow clock_window;
    public Gtk.SpinButton x_spin;
    public Gtk.SpinButton y_spin;
    private bool updating_pos_spins = false;

    public void update_position_spins(int x, int y) {
        updating_pos_spins = true;
        if (x_spin != null && (int)x_spin.value != x) x_spin.value = x;
        if (y_spin != null && (int)y_spin.value != y) y_spin.value = y;
        updating_pos_spins = false;
    }

    public OptionsDialog(NixieClockWindow parent_window) {
        Object(use_header_bar: 1);
        title = "Nixie Clock Options";

        set_resizable(true);
        set_default_size(540, 720);

        clock_window = parent_window;

        var content = get_content_area() as Gtk.Box;
        content.margin = 6;

        var notebook = new Gtk.Notebook();

        // --------------------------------------------------------------------
        // TAB 1: DISPLAY & GEOMETRY
        // --------------------------------------------------------------------
        var tab_display = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        tab_display.margin = 14;

        int wx, wy;
        parent_window.get_current_position(out wx, out wy);
        var pos_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        pos_box.pack_start(new Gtk.Label("Position (X, Y):"), false, false, 0);

        x_spin = new Gtk.SpinButton.with_range(-2000, 7680, 10);
        y_spin = new Gtk.SpinButton.with_range(-2000, 4320, 10);
        x_spin.value = wx;
        y_spin.value = wy;

        x_spin.value_changed.connect(() => {
            if (updating_pos_spins) return;
            parent_window.apply_window_position((int)x_spin.value, (int)y_spin.value);
            clock_window.save_config();
        });
        y_spin.value_changed.connect(() => {
            if (updating_pos_spins) return;
            parent_window.apply_window_position((int)x_spin.value, (int)y_spin.value);
            clock_window.save_config();
        });
        pos_box.pack_end(y_spin, false, false, 0);
        pos_box.pack_end(x_spin, false, false, 0);
        tab_display.pack_start(pos_box, false, false, 0);

        // Window Type Hint Option Dropdown with Restart Prompt
        var hint_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        hint_box.pack_start(new Gtk.Label("Window Type Hint:"), false, false, 0);
        var hint_combo = new Gtk.ComboBoxText();
        hint_combo.append_text("Auto (Default)");
        hint_combo.append_text("Utility");
        hint_combo.append_text("Dock");
        hint_combo.active = clock_window.window_type_hint_mode;
        hint_combo.set_tooltip_text("Forces a specific window type hint. Most window managers require a restart to apply hints.");
        
        hint_combo.changed.connect(() => {
            if (hint_combo.active != clock_window.window_type_hint_mode) {
                clock_window.window_type_hint_mode = hint_combo.active;
                clock_window.save_config();

                var msg_dialog = new Gtk.MessageDialog(
                    this,
                    Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.QUESTION,
                    Gtk.ButtonsType.YES_NO,
                    "Window Type Hint changed. Would you like to restart the clock now to apply it?"
                );
                msg_dialog.response.connect((response_id) => {
                    if (response_id == Gtk.ResponseType.YES) {
                        string[] argv = NixieClockWindow.saved_args;
                        try {
                            GLib.Process.spawn_async(null, argv, null, GLib.SpawnFlags.SEARCH_PATH, null, null);
                        } catch (Error e) {
                            // Fallback if spawn fails: try standard program path execution
                            try {
                                GLib.Process.spawn_command_line_async("nixie-clock");
                            } catch (Error inner_e) {
                                stderr.printf("[ERROR] Failed to restart: %s\n", inner_e.message);
                            }
                        }
                        Gtk.main_quit();
                    }
                    msg_dialog.destroy();
                });
                msg_dialog.show();
            }
        });
        hint_box.pack_end(hint_combo, false, false, 0);
        tab_display.pack_start(hint_box, false, false, 0);

        var scale_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        scale_box.pack_start(new Gtk.Label("Clock Scale (up to 4K):"), false, false, 0);
        var scale_spin = new Gtk.SpinButton.with_range(0.5, 20.0, 0.1);
        scale_spin.value = clock_window.scale_factor;
        scale_spin.value_changed.connect(() => {
            clock_window.scale_factor = scale_spin.value;
            clock_window.update_window_geometry();
            clock_window.queue_redraw();
            clock_window.save_config();
        });

        var fit_screen_btn = new Gtk.Button.with_label("Fit Screen Height");
        fit_screen_btn.clicked.connect(() => {
            var display = Gdk.Display.get_default();
            var monitor = display.get_primary_monitor();
            if (monitor != null) {
                var geom = monitor.get_geometry();
                double target_scale = (double)geom.height / 180.0;
                scale_spin.value = target_scale;
            }
        });

        scale_box.pack_end(fit_screen_btn, false, false, 0);
        scale_box.pack_end(scale_spin, false, false, 0);
        tab_display.pack_start(scale_box, false, false, 0);

        var chk_24h = new Gtk.CheckButton.with_label("Use 24-Hour Clock Format");
        chk_24h.active = clock_window.use_24h;
        chk_24h.toggled.connect(() => {
            clock_window.use_24h = chk_24h.active;
            clock_window.update_window_geometry();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        tab_display.pack_start(chk_24h, false, false, 0);

        var chk_seconds = new Gtk.CheckButton.with_label("Show Seconds Tubes");
        chk_seconds.active = clock_window.show_seconds;
        chk_seconds.toggled.connect(() => {
            clock_window.show_seconds = chk_seconds.active;
            clock_window.update_window_geometry();
            clock_window.restart_timers();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        tab_display.pack_start(chk_seconds, false, false, 0);

        var chk_ampm_style = new Gtk.CheckButton.with_label("Match Digit Multi-Glow Style for AM/PM");
        chk_ampm_style.active = clock_window.ampm_match_digit_style;
        chk_ampm_style.toggled.connect(() => {
            clock_window.ampm_match_digit_style = chk_ampm_style.active;
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        tab_display.pack_start(chk_ampm_style, false, false, 0);

        var ampm_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        ampm_box.pack_start(new Gtk.Label("AM/PM Tube Alignment:"), false, false, 0);
        var ampm_combo = new Gtk.ComboBoxText();
        ampm_combo.append_text("Top");
        ampm_combo.append_text("Center");
        ampm_combo.append_text("Bottom");
        ampm_combo.active = clock_window.am_pm_alignment;
        ampm_combo.changed.connect(() => {
            clock_window.am_pm_alignment = ampm_combo.active;
            clock_window.invalidate_bg_cache();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        ampm_box.pack_end(ampm_combo, false, false, 0);
        tab_display.pack_start(ampm_box, false, false, 0);

        notebook.append_page(tab_display, new Gtk.Label("Display"));

        // --------------------------------------------------------------------
        // TAB 2: STYLE & COLORS
        // --------------------------------------------------------------------
        var tab_style = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        tab_style.margin = 14;

        var style_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        style_box.pack_start(new Gtk.Label("Visual Theme:"), false, false, 0);
        var style_combo = new Gtk.ComboBoxText();
        style_combo.append_text("Classic Nixie Tube");
        style_combo.append_text("Amber Glow");
        style_combo.append_text("Neon Cyan");
        style_combo.append_text("Deep Ice Blue");
        style_combo.append_text("Dark Stealth");
        style_combo.active = clock_window.clock_style - 1;
        style_combo.changed.connect(() => {
            clock_window.clock_style = style_combo.active + 1;
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        style_box.pack_end(style_combo, false, false, 0);
        tab_style.pack_start(style_box, false, false, 0);

        var color_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        color_box.pack_start(new Gtk.Label("Ambient Glow Color:"), false, false, 0);

        var color_combo = new Gtk.ComboBoxText();
        foreach (var preset in clock_window.color_presets) {
            color_combo.append_text(preset.name);
        }
        color_combo.append_text("Custom...");

        var color_btn = new Gtk.ColorButton();
        Gdk.RGBA init_rgba = Gdk.RGBA();
        init_rgba.red = clock_window.current_color.r;
        init_rgba.green = clock_window.current_color.g;
        init_rgba.blue = clock_window.current_color.b;
        init_rgba.alpha = 1.0;
        color_btn.set_rgba(init_rgba);
        color_btn.use_alpha = false;
        color_btn.sensitive = true;

        int custom_index = clock_window.color_presets.length;
        int active_color_idx = custom_index;

        if (clock_window.current_color.name != "Custom") {
            for (int i = 0; i < clock_window.color_presets.length; i++) {
                if (clock_window.color_presets[i].name == clock_window.current_color.name) {
                    active_color_idx = i;
                    break;
                }
            }
        }

        color_combo.active = active_color_idx;

        color_combo.changed.connect(() => {
            int idx = color_combo.active;
            if (idx == custom_index) {
                clock_window.current_color = clock_window.custom_color;
                Gdk.RGBA rgba = Gdk.RGBA();
                rgba.red = clock_window.custom_color.r;
                rgba.green = clock_window.custom_color.g;
                rgba.blue = clock_window.custom_color.b;
                rgba.alpha = 1.0;
                color_btn.set_rgba(rgba);
            } else if (idx >= 0 && idx < custom_index) {
                clock_window.current_color = clock_window.color_presets[idx];
                Gdk.RGBA rgba = Gdk.RGBA();
                rgba.red = clock_window.color_presets[idx].r;
                rgba.green = clock_window.color_presets[idx].g;
                rgba.blue = clock_window.color_presets[idx].b;
                rgba.alpha = 1.0;
                color_btn.set_rgba(rgba);
            }
            clock_window.queue_redraw();
            clock_window.save_config();
        });

        color_btn.color_set.connect(() => {
            Gdk.RGBA selected_rgba = color_btn.rgba;
            clock_window.custom_color.r = selected_rgba.red;
            clock_window.custom_color.g = selected_rgba.green;
            clock_window.custom_color.b = selected_rgba.blue;
            clock_window.current_color = clock_window.custom_color;

            if (color_combo.active != custom_index) {
                color_combo.active = custom_index;
            }

            clock_window.queue_redraw();
            clock_window.save_config();
        });

        color_box.pack_end(color_btn, false, false, 0);
        color_box.pack_end(color_combo, false, false, 0);
        tab_style.pack_start(color_box, false, false, 0);

        var dcolor_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        dcolor_box.pack_start(new Gtk.Label("Digit Core Line Color:"), false, false, 0);

        var dcolor_combo = new Gtk.ComboBoxText();
        foreach (var preset in clock_window.digit_color_presets) {
            dcolor_combo.append_text(preset.name);
        }
        dcolor_combo.append_text("Custom...");

        var dcolor_btn = new Gtk.ColorButton();
        Gdk.RGBA init_d_rgba = Gdk.RGBA();
        init_d_rgba.red = clock_window.current_digit_color.r;
        init_d_rgba.green = clock_window.current_digit_color.g;
        init_d_rgba.blue = clock_window.current_digit_color.b;
        init_d_rgba.alpha = 1.0;
        dcolor_btn.set_rgba(init_d_rgba);
        dcolor_btn.use_alpha = false;
        dcolor_btn.sensitive = true;

        int d_custom_index = clock_window.digit_color_presets.length;
        int active_dcolor_idx = d_custom_index;

        if (clock_window.current_digit_color.name != "Custom") {
            for (int i = 0; i < clock_window.digit_color_presets.length; i++) {
                if (clock_window.digit_color_presets[i].name == clock_window.current_digit_color.name) {
                    active_dcolor_idx = i;
                    break;
                }
            }
        }

        dcolor_combo.active = active_dcolor_idx;

        dcolor_combo.changed.connect(() => {
            int idx = dcolor_combo.active;
            if (idx == d_custom_index) {
                clock_window.current_digit_color = clock_window.custom_digit_color;
                Gdk.RGBA rgba = Gdk.RGBA();
                rgba.red = clock_window.custom_digit_color.r;
                rgba.green = clock_window.custom_digit_color.g;
                rgba.blue = clock_window.custom_digit_color.b;
                rgba.alpha = 1.0;
                dcolor_btn.set_rgba(rgba);
            } else if (idx >= 0 && idx < d_custom_index) {
                clock_window.current_digit_color = clock_window.digit_color_presets[idx];
                Gdk.RGBA rgba = Gdk.RGBA();
                rgba.red = clock_window.digit_color_presets[idx].r;
                rgba.green = clock_window.digit_color_presets[idx].g;
                rgba.blue = clock_window.digit_color_presets[idx].b;
                rgba.alpha = 1.0;
                dcolor_btn.set_rgba(rgba);
            }
            clock_window.queue_redraw();
            clock_window.save_config();
        });

        dcolor_btn.color_set.connect(() => {
            Gdk.RGBA selected_rgba = dcolor_btn.rgba;
            clock_window.custom_digit_color.r = selected_rgba.red;
            clock_window.custom_digit_color.g = selected_rgba.green;
            clock_window.custom_digit_color.b = selected_rgba.blue;
            clock_window.current_digit_color = clock_window.custom_digit_color;

            if (dcolor_combo.active != d_custom_index) {
                dcolor_combo.active = d_custom_index;
            }

            clock_window.queue_redraw();
            clock_window.save_config();
        });

        dcolor_box.pack_end(dcolor_btn, false, false, 0);
        dcolor_box.pack_end(dcolor_combo, false, false, 0);
        tab_style.pack_start(dcolor_box, false, false, 0);

        var chk_bg = new Gtk.CheckButton.with_label("Render Glass Tube Backgrounds");
        chk_bg.active = clock_window.show_tube_background;
        chk_bg.toggled.connect(() => {
            clock_window.show_tube_background = chk_bg.active;
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        tab_style.pack_start(chk_bg, false, false, 0);

        var alpha_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        alpha_box.pack_start(new Gtk.Label("Glass Tube Opacity:"), false, false, 0);
        var alpha_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0.1, 1.0, 0.05);
        alpha_scale.set_value(clock_window.tube_alpha);
        alpha_scale.value_changed.connect(() => {
            clock_window.tube_alpha = alpha_scale.get_value();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        alpha_box.pack_end(alpha_scale, true, true, 0);
        tab_style.pack_start(alpha_box, false, false, 0);

        notebook.append_page(tab_style, new Gtk.Label("Style & Colors"));

        // --------------------------------------------------------------------
        // TAB 3: EFFECTS & PULSING
        // --------------------------------------------------------------------
        var tab_effects = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        tab_effects.margin = 12;

        var frame_colon = new Gtk.Frame(" Colon Settings ");
        var box_colon = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        box_colon.margin = 8;

        var glow_thick_colons_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        glow_thick_colons_box.pack_start(new Gtk.Label("Glow Thickness:"), false, false, 0);
        var glow_thick_colons_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0.1, 2.0, 0.05);
        glow_thick_colons_scale.set_value(clock_window.glow_thickness_colons);
        glow_thick_colons_scale.value_changed.connect(() => {
            clock_window.glow_thickness_colons = glow_thick_colons_scale.get_value();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        glow_thick_colons_box.pack_end(glow_thick_colons_scale, true, true, 0);
        box_colon.pack_start(glow_thick_colons_box, false, false, 0);

        var chk_pulse_colon = new Gtk.CheckButton.with_label("Enable Colon Pulsing");
        chk_pulse_colon.active = clock_window.pulse_colon;
        chk_pulse_colon.toggled.connect(() => {
            clock_window.pulse_colon = chk_pulse_colon.active;
            clock_window.restart_timers();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        box_colon.pack_start(chk_pulse_colon, false, false, 0);

        var colon_max_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        colon_max_box.pack_start(new Gtk.Label("Max Brightness:"), false, false, 0);
        var colon_max_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0.1, 2.0, 0.05);
        colon_max_scale.set_value(clock_window.colon_max_brightness);
        colon_max_scale.value_changed.connect(() => {
            clock_window.colon_max_brightness = colon_max_scale.get_value();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        colon_max_box.pack_end(colon_max_scale, true, true, 0);
        box_colon.pack_start(colon_max_box, false, false, 0);

        var colon_min_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        colon_min_box.pack_start(new Gtk.Label("Min Brightness:"), false, false, 0);
        var colon_min_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.05);
        colon_min_scale.set_value(clock_window.colon_min_brightness);
        colon_min_scale.value_changed.connect(() => {
            clock_window.colon_min_brightness = colon_min_scale.get_value();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        colon_min_box.pack_end(colon_min_scale, true, true, 0);
        box_colon.pack_start(colon_min_box, false, false, 0);

        var colon_speed_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        colon_speed_box.pack_start(new Gtk.Label("Pulse Speed (Interval ms):"), false, false, 0);
        var colon_speed_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 20, 300, 10);
        colon_speed_scale.set_value(clock_window.colon_pulse_interval);
        colon_speed_scale.value_changed.connect(() => {
            clock_window.colon_pulse_interval = (int)colon_speed_scale.get_value();
            clock_window.restart_timers();
            clock_window.save_config();
        });
        colon_speed_box.pack_end(colon_speed_scale, true, true, 0);
        box_colon.pack_start(colon_speed_box, false, false, 0);

        frame_colon.add(box_colon);
        tab_effects.pack_start(frame_colon, false, false, 0);

        var frame_num = new Gtk.Frame(" Digit Settings ");
        var box_num = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        box_num.margin = 8;

        var glow_thick_digits_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        glow_thick_digits_box.pack_start(new Gtk.Label("Glow Thickness:"), false, false, 0);
        var glow_thick_digits_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0.1, 2.0, 0.05);
        glow_thick_digits_scale.set_value(clock_window.glow_thickness_digits);
        glow_thick_digits_scale.value_changed.connect(() => {
            clock_window.glow_thickness_digits = glow_thick_digits_scale.get_value();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        glow_thick_digits_box.pack_end(glow_thick_digits_scale, true, true, 0);
        box_num.pack_start(glow_thick_digits_box, false, false, 0);

        var chk_pulse_nums = new Gtk.CheckButton.with_label("Enable Digit Pulsing");
        chk_pulse_nums.active = clock_window.pulse_numbers;
        chk_pulse_nums.toggled.connect(() => {
            clock_window.pulse_numbers = chk_pulse_nums.active;
            clock_window.restart_timers();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        box_num.pack_start(chk_pulse_nums, false, false, 0);

        var num_max_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        num_max_box.pack_start(new Gtk.Label("Max Brightness:"), false, false, 0);
        var num_max_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0.1, 2.0, 0.05);
        num_max_scale.set_value(clock_window.number_max_brightness);
        num_max_scale.value_changed.connect(() => {
            clock_window.number_max_brightness = num_max_scale.get_value();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        num_max_box.pack_end(num_max_scale, true, true, 0);
        box_num.pack_start(num_max_box, false, false, 0);

        var num_min_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        num_min_box.pack_start(new Gtk.Label("Min Brightness:"), false, false, 0);
        var num_min_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.05);
        num_min_scale.set_value(clock_window.number_min_brightness);
        num_min_scale.value_changed.connect(() => {
            clock_window.number_min_brightness = num_min_scale.get_value();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        num_min_box.pack_end(num_min_scale, true, true, 0);
        box_num.pack_start(num_min_box, false, false, 0);

        var num_speed_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        num_speed_box.pack_start(new Gtk.Label("Pulse Speed (Interval ms):"), false, false, 0);
        var num_speed_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 20, 300, 10);
        num_speed_scale.set_value(clock_window.number_pulse_interval);
        num_speed_scale.value_changed.connect(() => {
            clock_window.number_pulse_interval = (int)num_speed_scale.get_value();
            clock_window.restart_timers();
            clock_window.save_config();
        });
        num_speed_box.pack_end(num_speed_scale, true, true, 0);
        box_num.pack_start(num_speed_box, false, false, 0);

        frame_num.add(box_num);
        tab_effects.pack_start(frame_num, false, false, 0);

        var border_bright_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        border_bright_box.pack_start(new Gtk.Label("Tube Frame & Mesh Glow:"), false, false, 0);
        var border_bright_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0.0, 2.0, 0.1);
        border_bright_scale.set_value(clock_window.border_brightness);
        border_bright_scale.value_changed.connect(() => {
            clock_window.border_brightness = border_bright_scale.get_value();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        border_bright_box.pack_end(border_bright_scale, true, true, 0);
        tab_effects.pack_start(border_bright_box, false, false, 0);

        notebook.append_page(tab_effects, new Gtk.Label("Glow & Effects"));

        content.pack_start(notebook, true, true, 0);

        add_button("Close", Gtk.ResponseType.CLOSE);
        response.connect((resp) => {
            clock_window.save_config();
            this.destroy();
        });

        show_all();
    }
}

public int main(string[] args) {
    NixieClockWindow.saved_args = args;
    GLib.Environment.set_variable("GDK_BACKEND", "x11", true);

    Gtk.init(ref args);
    var app = new NixieClockWindow();
    app.destroy.connect(() => {
        app.save_config();
        Gtk.main_quit();
    });
    app.show_all();
    Gtk.main();
    return 0;
}