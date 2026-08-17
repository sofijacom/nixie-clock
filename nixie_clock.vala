/*
 * Nixie Clock Widget
 * Copyright (C) 2026
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

using Gtk;
using Cairo;
using GLib;
using Pango;

public class OptionsDialog : Gtk.Dialog {
    public NixieClockWindow clock_window;
    
    public OptionsDialog(NixieClockWindow parent_window) {
        Object(use_header_bar: 1);
        title = "Nixie Clock Options";
        transient_for = parent_window;
        modal = true;
        set_default_size(380, 660);
        
        clock_window = parent_window;
        
        var content = get_content_area() as Gtk.Box;
        content.margin = 16;
        content.spacing = 10;
        
        // 1. Style Selection
        var style_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        style_box.pack_start(new Gtk.Label("Clock Style:"), false, false, 0);
        var style_combo = new Gtk.ComboBoxText();
        style_combo.append("0", "Modern Minimalist");
        style_combo.append("1", "Authentic Real Tubes");
        style_combo.append("2", "Cyberpunk Neon");
        style_combo.append("3", "Vacuum VFD Blue");
        style_combo.append("4", "Terminal Scanline VFD");
        style_combo.active_id = clock_window.clock_style.to_string();
        style_combo.changed.connect(() => {
            clock_window.clock_style = int.parse(style_combo.get_active_id());
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        style_box.pack_end(style_combo, true, true, 0);
        content.pack_start(style_box, false, false, 0);
        
        // 2. 24h format
        var format_check = new Gtk.CheckButton.with_label("Use 24-Hour Format");
        format_check.active = clock_window.use_24h;
        format_check.toggled.connect(() => {
            clock_window.use_24h = format_check.active;
            clock_window.update_window_geometry();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        content.pack_start(format_check, false, false, 0);
        
        // 2.5 Show Seconds
        var seconds_check = new Gtk.CheckButton.with_label("Show Seconds");
        seconds_check.active = clock_window.show_seconds;
        seconds_check.toggled.connect(() => {
            clock_window.show_seconds = seconds_check.active;
            clock_window.update_window_geometry();
            clock_window.restart_timers();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        content.pack_start(seconds_check, false, false, 0);
        
        // 2.7 Animation Mode (CPU Optimization)
        var anim_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        anim_box.pack_start(new Gtk.Label("Animation / CPU Mode:"), false, false, 0);
        var anim_combo = new Gtk.ComboBoxText();
        anim_combo.append("0", "Dynamic Pulse (Fast)");
        anim_combo.append("1", "Dynamic Pulse (Normal)");
        anim_combo.append("2", "Static (Lowest CPU)");
        anim_combo.active_id = clock_window.animation_mode.to_string();
        anim_combo.changed.connect(() => {
            clock_window.animation_mode = int.parse(anim_combo.get_active_id());
            clock_window.restart_timers();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        anim_box.pack_end(anim_combo, true, true, 0);
        content.pack_start(anim_box, false, false, 0);
        
        // 2.8 AM/PM Alignment
        var am_align_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        am_align_box.pack_start(new Gtk.Label("AM/PM Tube Alignment:"), false, false, 0);
        var am_align_combo = new Gtk.ComboBoxText();
        am_align_combo.append("0", "Top");
        am_align_combo.append("1", "Center");
        am_align_combo.append("2", "Bottom");
        am_align_combo.active_id = clock_window.am_pm_alignment.to_string();
        am_align_combo.changed.connect(() => {
            clock_window.am_pm_alignment = int.parse(am_align_combo.get_active_id());
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        am_align_box.pack_end(am_align_combo, true, true, 0);
        content.pack_start(am_align_box, false, false, 0);
        
        // 3. Color Theme Selector & Custom Color Picker
        var color_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        color_box.pack_start(new Gtk.Label("Glow Color:"), false, false, 0);
        
        var color_combo = new Gtk.ComboBoxText();
        foreach (var col in clock_window.color_presets) {
            color_combo.append(col.name, col.name);
        }
        color_combo.append("Custom", "Custom Color");
        color_combo.active_id = (clock_window.current_color.name == "Custom") ? "Custom" : clock_window.current_color.name;
        
        var color_btn = new Gtk.ColorButton();
        Gdk.RGBA initial_rgba = Gdk.RGBA();
        initial_rgba.red = clock_window.current_color.r;
        initial_rgba.green = clock_window.current_color.g;
        initial_rgba.blue = clock_window.current_color.b;
        initial_rgba.alpha = 1.0;
        color_btn.set_rgba(initial_rgba);
        color_btn.set_sensitive(true);
        
        bool updating_ui = false;
        
        color_combo.changed.connect(() => {
            if (updating_ui) return;
            string name = color_combo.get_active_id();
            if (name != "Custom") {
                foreach (var col in clock_window.color_presets) {
                    if (col.name == name) {
                        clock_window.current_color = col;
                        updating_ui = true;
                        Gdk.RGBA c = Gdk.RGBA();
                        c.red = col.r; c.green = col.g; c.blue = col.b; c.alpha = 1.0;
                        color_btn.set_rgba(c);
                        updating_ui = false;
                        break;
                    }
                }
            }
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        
        color_btn.color_set.connect(() => {
            if (updating_ui) return;
            Gdk.RGBA c = color_btn.get_rgba();
            clock_window.current_color = NixieClockWindow.TubeColor() { r = c.red, g = c.green, b = c.blue, name = "Custom" };
            updating_ui = true;
            color_combo.active_id = "Custom";
            updating_ui = false;
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        
        color_box.pack_start(color_combo, true, true, 0);
        color_box.pack_start(color_btn, false, false, 0);
        content.pack_start(color_box, false, false, 0);
        
        content.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 4);
        
        // 4. Size Scale
        var size_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        size_box.pack_start(new Gtk.Label("Size Scale:"), false, false, 0);
        var size_spin = new Gtk.SpinButton.with_range(0.3, 20.0, 0.1);
        size_spin.value = clock_window.scale_factor;
        size_spin.value_changed.connect(() => {
            clock_window.scale_factor = size_spin.value;
            clock_window.update_window_geometry();
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        size_box.pack_end(size_spin, true, true, 0);
        content.pack_start(size_box, false, false, 0);
        
        // 5. Position X & Y
        int wx, wy;
        parent_window.get_position(out wx, out wy);
        
        var pos_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        pos_box.pack_start(new Gtk.Label("Position (X, Y):"), false, false, 0);
        var x_spin = new Gtk.SpinButton.with_range(0, 4000, 10);
        var y_spin = new Gtk.SpinButton.with_range(0, 3000, 10);
        x_spin.value = wx;
        y_spin.value = wy;
        x_spin.value_changed.connect(() => { parent_window.move((int)x_spin.value, (int)y_spin.value); clock_window.save_config(); });
        y_spin.value_changed.connect(() => { parent_window.move((int)x_spin.value, (int)y_spin.value); clock_window.save_config(); });
        pos_box.pack_end(y_spin, true, true, 0);
        pos_box.pack_end(x_spin, true, true, 0);
        content.pack_start(pos_box, false, false, 0);
        
        content.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 4);
        
        // 6. Tube Transparency
        var alpha_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        alpha_box.pack_start(new Gtk.Label("Tube Transparency:"), false, false, 0);
        var alpha_spin = new Gtk.SpinButton.with_range(0.1, 1.0, 0.05);
        alpha_spin.digits = 2;
        alpha_spin.value = clock_window.tube_alpha;
        alpha_spin.value_changed.connect(() => {
            clock_window.tube_alpha = alpha_spin.value;
            clock_window.queue_redraw();
            clock_window.save_config();
        });
        alpha_box.pack_end(alpha_spin, true, true, 0);
        content.pack_start(alpha_box, false, false, 0);
        
        // 7. Colon Pulse Rate
        var colon_rate_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        colon_rate_box.pack_start(new Gtk.Label("Colon Pulse Speed (ms):"), false, false, 0);
        var colon_spin = new Gtk.SpinButton.with_range(40, 300, 10);
        colon_spin.value = clock_window.colon_pulse_interval;
        colon_spin.value_changed.connect(() => {
            clock_window.colon_pulse_interval = (int)colon_spin.value;
            clock_window.restart_timers();
            clock_window.save_config();
        });
        colon_rate_box.pack_end(colon_spin, true, true, 0);
        content.pack_start(colon_rate_box, false, false, 0);
        
        // 8. Number Pulse Depth
        var num_rate_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        num_rate_box.pack_start(new Gtk.Label("Number Pulse Depth:"), false, false, 0);
        var num_spin = new Gtk.SpinButton.with_range(0.0, 1.0, 0.1);
        num_spin.digits = 1;
        num_spin.value = clock_window.number_pulse_depth;
        num_spin.value_changed.connect(() => {
            clock_window.number_pulse_depth = num_spin.value;
            clock_window.save_config();
        });
        num_rate_box.pack_end(num_spin, true, true, 0);
        content.pack_start(num_rate_box, false, false, 0);
        
        // 9. Minimum Darkness
        var dark_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        dark_box.pack_start(new Gtk.Label("Min Darkness (Alpha):"), false, false, 0);
        var dark_spin = new Gtk.SpinButton.with_range(0.01, 0.5, 0.02);
        dark_spin.digits = 2;
        dark_spin.value = clock_window.colon_min_alpha;
        dark_spin.value_changed.connect(() => {
            clock_window.colon_min_alpha = dark_spin.value;
            clock_window.save_config();
        });
        dark_box.pack_end(dark_spin, true, true, 0);
        content.pack_start(dark_box, false, false, 0);
        
        add_button("Close", Gtk.ResponseType.CLOSE);
        response.connect((resp) => {
            clock_window.save_config();
            this.destroy();
        });
        
        show_all();
    }
}

public class NixieClockWindow : Gtk.Window {
    private Gtk.DrawingArea drawing_area;
    public int clock_style = 1;
    public bool use_24h = false;
    public bool show_seconds = true;
    public int animation_mode = 1;
    public int am_pm_alignment = 0;
    public new double scale_factor = 1.0;
    public double tube_alpha = 0.95;
    
    public int colon_pulse_interval = 120;
    public double number_pulse_depth = 0.3;
    public double colon_min_alpha = 0.2;
    
    private double colon_alpha = 1.0;
    private double colon_fade_dir = -0.05;
    private double number_glow_pulse = 0.0;
    
    private uint colon_timer_id = 0;
    private uint clock_timer_id = 0;
    private string last_drawn_time_str = "";
    
    public struct TubeColor {
        public double r;
        public double g;
        public double b;
        public string name;
    }
    
    public TubeColor current_color = TubeColor() { r = 1.0, g = 0.33, b = 0.0, name = "Warm Amber" };
    
    public TubeColor[] color_presets = {
        TubeColor() { r = 1.0, g = 0.33, b = 0.0, name = "Warm Amber" },
        TubeColor() { r = 0.2, g = 0.85, b = 1.0, name = "Neon Cyan" },
        TubeColor() { r = 0.1, g = 1.0, b = 0.4, name = "Emerald Green" },
        TubeColor() { r = 0.6, g = 0.8, b = 1.0, name = "Ice Blue" },
        TubeColor() { r = 1.0, g = 0.2, b = 0.6, name = "Hot Magenta" }
    };
    
    public NixieClockWindow() {
        set_title("Nixie Clock");
        
        int saved_x = -1, saved_y = -1;
        bool has_saved_pos = load_config(out saved_x, out saved_y);
        
        update_window_geometry();
        
        if (has_saved_pos) {
            move(saved_x, saved_y);
        } else {
            set_position(Gtk.WindowPosition.CENTER);
        }
        
        set_decorated(false);
        set_type_hint(Gdk.WindowTypeHint.DOCK);
        set_app_paintable(true);
        
        var visual = get_screen().get_rgba_visual();
        if (visual != null) {
            set_visual(visual);
        }
        
        set_keep_below(true);
        stick();
        set_skip_taskbar_hint(true);
        set_skip_pager_hint(true);
        
        drawing_area = new Gtk.DrawingArea();
        drawing_area.set_app_paintable(true);
        add(drawing_area);
        
        drawing_area.draw.connect(on_draw);
        drawing_area.set_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.POINTER_MOTION_MASK);
        drawing_area.button_press_event.connect(on_button_press);
        
        start_timers();
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
                if (kf.has_key("Settings", "animation_mode")) animation_mode = kf.get_integer("Settings", "animation_mode");
                if (kf.has_key("Settings", "am_pm_alignment")) am_pm_alignment = kf.get_integer("Settings", "am_pm_alignment");
                if (kf.has_key("Settings", "scale_factor")) scale_factor = kf.get_double("Settings", "scale_factor");
                if (kf.has_key("Settings", "tube_alpha")) tube_alpha = kf.get_double("Settings", "tube_alpha");
                if (kf.has_key("Settings", "colon_pulse_interval")) colon_pulse_interval = kf.get_integer("Settings", "colon_pulse_interval");
                if (kf.has_key("Settings", "number_pulse_depth")) number_pulse_depth = kf.get_double("Settings", "number_pulse_depth");
                if (kf.has_key("Settings", "colon_min_alpha")) colon_min_alpha = kf.get_double("Settings", "colon_min_alpha");
                
                if (kf.has_key("Settings", "glow_color")) {
                    string col_name = kf.get_string("Settings", "glow_color");
                    if (col_name == "Custom" && kf.has_key("Settings", "glow_r")) {
                        current_color = TubeColor() {
                            r = kf.get_double("Settings", "glow_r"),
                            g = kf.get_double("Settings", "glow_g"),
                            b = kf.get_double("Settings", "glow_b"),
                            name = "Custom"
                        };
                    } else {
                        foreach (var col in color_presets) {
                            if (col.name == col_name) {
                                current_color = col;
                                break;
                            }
                        }
                    }
                }
                
                if (kf.has_key("Settings", "window_x") && kf.has_key("Settings", "window_y")) {
                    out_x = kf.get_integer("Settings", "window_x");
                    out_y = kf.get_integer("Settings", "window_y");
                    return true;
                }
            }
        } catch (Error e) {
            // Configuration defaults
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
            kf.set_integer("Settings", "animation_mode", animation_mode);
            kf.set_integer("Settings", "am_pm_alignment", am_pm_alignment);
            kf.set_double("Settings", "scale_factor", scale_factor);
            kf.set_double("Settings", "tube_alpha", tube_alpha);
            kf.set_integer("Settings", "colon_pulse_interval", colon_pulse_interval);
            kf.set_double("Settings", "number_pulse_depth", number_pulse_depth);
            kf.set_double("Settings", "colon_min_alpha", colon_min_alpha);
            kf.set_string("Settings", "glow_color", current_color.name);
            if (current_color.name == "Custom") {
                kf.set_double("Settings", "glow_r", current_color.r);
                kf.set_double("Settings", "glow_g", current_color.g);
                kf.set_double("Settings", "glow_b", current_color.b);
            }
            
            int wx, wy;
            get_position(out wx, out wy);
            kf.set_integer("Settings", "window_x", wx);
            kf.set_integer("Settings", "window_y", wy);
            
            string data = kf.to_data(null);
            FileUtils.set_contents(path, data);
        } catch (Error e) {
            warning("Failed to save configuration: %s", e.message);
        }
    }
    
    public void update_window_geometry() {
        int base_w;
        if (show_seconds) {
            base_w = use_24h ? 520 : 600;
        } else {
            base_w = use_24h ? 340 : 420;
        }
        int base_h = 160;
        set_default_size((int)(base_w * scale_factor), (int)(base_h * scale_factor));
        resize((int)(base_w * scale_factor), (int)(base_h * scale_factor));
    }
    
    public void start_timers() {
        if (colon_timer_id != 0) Source.remove(colon_timer_id);
        if (clock_timer_id != 0) Source.remove(clock_timer_id);
        
        colon_timer_id = 0;
        clock_timer_id = 0;
        
        if (animation_mode == 2) {
            colon_alpha = 1.0;
            number_glow_pulse = 0.0;
            
            if (show_seconds) {
                clock_timer_id = GLib.Timeout.add(1000, () => {
                    drawing_area.queue_draw();
                    return true;
                });
            } else {
                clock_timer_id = GLib.Timeout.add(1000, () => {
                    var now = new DateTime.now_local();
                    string current_time_str = "%02d:%02d".printf(now.get_hour(), now.get_minute());
                    if (current_time_str != last_drawn_time_str) {
                        drawing_area.queue_draw();
                    }
                    return true;
                });
            }
        } else {
            int interval = (animation_mode == 0) ? 60 : colon_pulse_interval;
            colon_timer_id = GLib.Timeout.add(interval, () => {
                colon_alpha += colon_fade_dir;
                if (colon_alpha <= colon_min_alpha) {
                    colon_alpha = colon_min_alpha;
                    colon_fade_dir = 0.05;
                } else if (colon_alpha >= 1.0) {
                    colon_alpha = 1.0;
                    colon_fade_dir = -0.05;
                }
                number_glow_pulse = (1.0 - colon_alpha) * number_pulse_depth;
                drawing_area.queue_draw();
                return true;
            });
        }
    }
    
    public void restart_timers() {
        start_timers();
    }
    
    public void queue_redraw() {
        drawing_area.queue_draw();
    }
    
    private bool on_button_press(Gdk.EventButton event) {
        if (event.button == 1) {
            this.begin_move_drag((int)event.button, (int)event.x_root, (int)event.y_root, event.time);
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
            var dialog = new OptionsDialog(this);
            dialog.show();
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
    
    private bool on_draw(Cairo.Context cr) {
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
        
        last_drawn_time_str = "%02d:%02d".printf(hour, minute);
        
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
        
        double cur_x = start_x;
        
        draw_tube(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(hour)[0].to_string());
        cur_x += tube_w + spacing;
        draw_tube(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(hour)[1].to_string());
        cur_x += tube_w + spacing;
        
        draw_colon(cr, cur_x, start_y, colon_w, tube_h, colon_alpha);
        cur_x += colon_w + spacing;
        
        draw_tube(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(minute)[0].to_string());
        cur_x += tube_w + spacing;
        draw_tube(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(minute)[1].to_string());
        cur_x += tube_w + spacing;
        
        if (show_seconds) {
            draw_colon(cr, cur_x, start_y, colon_w, tube_h, colon_alpha);
            cur_x += colon_w + spacing;
            
            draw_tube(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(second)[0].to_string());
            cur_x += tube_w + spacing;
            draw_tube(cr, cur_x, start_y, tube_w, tube_h, "%02d".printf(second)[1].to_string());
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
            draw_am_pm_tube(cr, cur_x, am_y, am_w, am_h, is_pm);
        }
        
        return false;
    }
    
    private void draw_tube_background(Cairo.Context cr, double x, double y, double w, double h) {
        if (clock_style == 1) {
            // ORIGINAL AUTHENTIC REAL TUBES BACKGROUND
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
    
    private void draw_tube(Cairo.Context cr, double x, double y, double w, double h, string digit_str) {
        draw_tube_background(cr, x, y, w, h);
        
        if (clock_style == 1) {
            // ORIGINAL AUTHENTIC TUBE GLASS BORDER & WIRE MESH
            cr.set_source_rgba(0.4, 0.3, 0.2, 0.8);
            cr.set_line_width(1.5 * scale_factor);
            cr.stroke();
            
            // Original grid mesh overlay
            cr.set_source_rgba(0.3, 0.2, 0.1, 0.25);
            cr.set_line_width(0.5 * scale_factor);
            double grid_step = 6.0 * scale_factor;
            for (double gx = x + (4.0 * scale_factor); gx < x + w - (4.0 * scale_factor); gx += grid_step) {
                cr.move_to(gx, y + (6.0 * scale_factor));
                cr.line_to(gx, y + h - (6.0 * scale_factor));
                cr.stroke();
            }
            for (double gy = y + (6.0 * scale_factor); gy < y + h - (6.0 * scale_factor); gy += grid_step) {
                cr.move_to(x + (4.0 * scale_factor), gy);
                cr.line_to(x + w - (4.0 * scale_factor), gy);
                cr.stroke();
            }
        } else {
            // NEW STYLES BORDER & MESH
            if (clock_style == 2 || clock_style == 4) {
                cr.set_source_rgba(current_color.r * 0.9, current_color.g * 0.9, current_color.b * 0.9, 0.95);
            } else if (clock_style == 3) {
                cr.set_source_rgba(current_color.r * 0.85, current_color.g * 0.85, current_color.b * 0.85, 0.9);
            } else {
                cr.set_source_rgba(0.25, 0.65, 0.85, 0.85);
            }
            cr.set_line_width(((clock_style == 2 || clock_style == 4) ? 2.0 : 1.5) * scale_factor);
            cr.stroke();
            
            if (clock_style == 2 || clock_style == 4) {
                cr.set_source_rgba(current_color.r, current_color.g, current_color.b, (clock_style == 4) ? 0.14 : 0.15);
                cr.set_line_width(0.5 * scale_factor);
                double step = (clock_style == 4) ? (4.5 * scale_factor) : (10.0 * scale_factor);
                for (double i = y + (8 * scale_factor); i < y + h - (8 * scale_factor); i += step) {
                    cr.move_to(x + (3.0 * scale_factor), i);
                    cr.line_to(x + w - (3.0 * scale_factor), i);
                    cr.stroke();
                }
            }
        }
        
        cr.save();
        var layout = Pango.cairo_create_layout(cr);
        layout.set_text(digit_str, -1);
        int font_size = (int)(62 * scale_factor);
        var desc = Pango.FontDescription.from_string("Sans Bold %d".printf(font_size));
        layout.set_font_description(desc);
        
        int text_w, text_h;
        layout.get_pixel_size(out text_w, out text_h);
        
        double text_x = x + (w - text_w) / 2.0 - (2.0 * scale_factor);
        double text_y = y + (h - text_h) / 2.0 - (3.0 * scale_factor);
        
        cr.move_to(text_x, text_y);
        Pango.cairo_layout_path(cr, layout);
        
        double alpha_mod = Math.fmax(0.1, 1.0 - number_glow_pulse);
        if (clock_style == 1) {
            // ORIGINAL AUTHENTIC REAL TUBES DIGIT GLOW PIPELINE
            cr.set_source_rgba(current_color.r, current_color.g * 0.4, current_color.b * 0.1, 0.15 * alpha_mod);
            cr.set_line_width(12.0 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(current_color.r, current_color.g * 0.5, current_color.b * 0.1, 0.3 * alpha_mod);
            cr.set_line_width(6.0 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(current_color.r, current_color.g * 0.8, current_color.b * 0.2, 0.8 * alpha_mod);
            cr.set_line_width(2.5 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(1.0, 0.9, 0.7, alpha_mod);
            cr.set_line_width(1.0 * scale_factor);
            cr.stroke();
        } else if (clock_style > 1) {
            cr.set_source_rgba(current_color.r * 0.9, current_color.g * 0.8, current_color.b, 0.14 * alpha_mod);
            cr.set_line_width(11.0 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.32 * alpha_mod);
            cr.set_line_width(5.5 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(Math.fmin(1.0, current_color.r * 1.1), Math.fmin(1.0, current_color.g * 1.1), Math.fmin(1.0, current_color.b * 1.1), 0.88 * alpha_mod);
            cr.set_line_width(2.0 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(1.0, 0.96, 0.88, alpha_mod);
            cr.set_line_width(0.7 * scale_factor);
            cr.stroke();
        } else {
            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.22 * alpha_mod);
            cr.set_line_width(6.0 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.92 * alpha_mod);
            cr.set_line_width(1.8 * scale_factor);
            cr.stroke();
        }
        
        cr.restore();
    }
    
    private void draw_colon(Cairo.Context cr, double x, double y, double w, double h, double alpha) {
        double cx = x + w / 2.0;
        double dot_r = 3.8 * scale_factor;
        double y1 = y + h * 0.35;
        double y2 = y + h * 0.65;
        
        cr.save();
        cr.arc(cx, y1, dot_r * 1.6, 0, 2.0 * Math.PI);
        cr.set_source_rgba(current_color.r, current_color.g, current_color.b, alpha * 0.3);
        cr.fill();
        
        cr.arc(cx, y1, dot_r, 0, 2.0 * Math.PI);
        cr.set_source_rgba(current_color.r, current_color.g, current_color.b, alpha);
        cr.fill();
        
        cr.arc(cx, y2, dot_r * 1.6, 0, 2.0 * Math.PI);
        cr.set_source_rgba(current_color.r, current_color.g, current_color.b, alpha * 0.3);
        cr.fill();
        
        cr.arc(cx, y2, dot_r, 0, 2.0 * Math.PI);
        cr.set_source_rgba(current_color.r, current_color.g, current_color.b, alpha);
        cr.fill();
        cr.restore();
    }
    
    private void draw_am_pm_tube(Cairo.Context cr, double x, double y, double w, double h, bool is_pm) {
        draw_tube_background(cr, x, y, w, h);
        
        if (clock_style == 1) {
            cr.set_source_rgba(0.4, 0.3, 0.2, 0.8);
            cr.set_line_width(1.2 * scale_factor);
            cr.stroke();
            
            cr.set_source_rgba(0.3, 0.2, 0.1, 0.25);
            cr.set_line_width(0.5 * scale_factor);
            double grid_step = 6.0 * scale_factor;
            for (double gx = x + (3.0 * scale_factor); gx < x + w - (3.0 * scale_factor); gx += grid_step) {
                cr.move_to(gx, y + (4.0 * scale_factor));
                cr.line_to(gx, y + h - (4.0 * scale_factor));
                cr.stroke();
            }
            for (double gy = y + (4.0 * scale_factor); gy < y + h - (4.0 * scale_factor); gy += grid_step) {
                cr.move_to(x + (3.0 * scale_factor), gy);
                cr.line_to(x + w - (3.0 * scale_factor), gy);
                cr.stroke();
            }
        } else {
            if (clock_style == 2 || clock_style == 4) {
                cr.set_source_rgba(current_color.r * 0.9, current_color.g * 0.9, current_color.b * 0.9, 0.95);
            } else if (clock_style == 3) {
                cr.set_source_rgba(current_color.r * 0.85, current_color.g * 0.85, current_color.b * 0.85, 0.9);
            } else {
                cr.set_source_rgba(0.25, 0.65, 0.85, 0.85);
            }
            cr.set_line_width(((clock_style == 2 || clock_style == 4) ? 1.8 : 1.2) * scale_factor);
            cr.stroke();
            
            if (clock_style == 2 || clock_style == 4) {
                cr.set_source_rgba(current_color.r, current_color.g, current_color.b, (clock_style == 4) ? 0.14 : 0.15);
                cr.set_line_width(0.5 * scale_factor);
                double step = (clock_style == 4) ? (4.5 * scale_factor) : (10.0 * scale_factor);
                for (double i = y + (5 * scale_factor); i < y + h - (5 * scale_factor); i += step) {
                    cr.move_to(x + (2.5 * scale_factor), i);
                    cr.line_to(x + w - (2.5 * scale_factor), i);
                    cr.stroke();
                }
            }
        }
        
        cr.save();
        var layout = Pango.cairo_create_layout(cr);
        layout.set_text(is_pm ? "pm" : "am", -1);
        int font_size = (int)(18 * scale_factor);
        var desc = Pango.FontDescription.from_string("Sans Bold %d".printf(font_size));
        layout.set_font_description(desc);
        
        int text_w, text_h;
        layout.get_pixel_size(out text_w, out text_h);
        
        double text_x = x + (w - text_w) / 2.0;
        double text_y = y + (h - text_h) / 2.0;
        
        cr.move_to(text_x, text_y);
        Pango.cairo_layout_path(cr, layout);
        
        double alpha_mod = Math.fmax(0.1, 1.0 - number_glow_pulse);
        if (clock_style == 1) {
            cr.set_source_rgba(current_color.r, current_color.g * 0.4, current_color.b * 0.1, 0.15 * alpha_mod);
            cr.set_line_width(7.0 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(current_color.r, current_color.g * 0.5, current_color.b * 0.1, 0.3 * alpha_mod);
            cr.set_line_width(3.5 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(current_color.r, current_color.g * 0.8, current_color.b * 0.2, 0.8 * alpha_mod);
            cr.set_line_width(1.5 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(1.0, 0.9, 0.7, alpha_mod);
            cr.set_line_width(0.7 * scale_factor);
            cr.stroke();
        } else if (clock_style > 1) {
            cr.set_source_rgba(current_color.r * 0.9, current_color.g * 0.8, current_color.b, 0.14 * alpha_mod);
            cr.set_line_width(6.0 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.32 * alpha_mod);
            cr.set_line_width(3.0 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(Math.fmin(1.0, current_color.r * 1.1), Math.fmin(1.0, current_color.g * 1.1), Math.fmin(1.0, current_color.b * 1.1), 0.88 * alpha_mod);
            cr.set_line_width(1.2 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(1.0, 0.96, 0.88, alpha_mod);
            cr.set_line_width(0.5 * scale_factor);
            cr.stroke();
        } else {
            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.22 * alpha_mod);
            cr.set_line_width(4.0 * scale_factor);
            cr.stroke_preserve();
            
            cr.set_source_rgba(current_color.r, current_color.g, current_color.b, 0.92 * alpha_mod);
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

public int main(string[] args) {
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