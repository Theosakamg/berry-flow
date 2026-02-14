#-
 * Water Counter Management in Berry - YF-B6 Sensor
 * Spec: Q [L/min] = fpulse[Hz] / 6.6
 * Monitors 2 counters: Global (Hot+Cold) and Hot Water
 * Sampling at 100ms like original Tasmota script
 * Calculates flow rates and publishes to MQTT
 * Web UI for configuration and monitoring
 -#

import persist
import mqtt
import webserver
import string
import json
import string

# Single counter management class
class Counter
    var __index              # Hardware counter index (0 or 1)
    var __name               # Display name

    var _delta               # Last delta pulses
    var _initial_offset      # Calibration offset
    var _k_factor            # K-factor for YF-B6: Q[L/min] = f[Hz]/K (K=6.6)
    var _liter_acc           # Accumulated liters
    var _total_pulses        # Total pulses counted
    var _hw_offset           # Logical offset to keep cumulative pulses monotonic
    var _raw_counter_last    # Last raw hardware counter read
    var flow                 # Current flow rate (l/min) (public for display)
    var total_liter          # Total liters with offset (public for display)
    var total_liter_last     # Last total liters (for delta calculation if needed)
    var total_pulses_last   # Last total pulses (for delta calculation if needed)



    # Initialize internal variables
    def _init()
        self._delta = 0
        self._initial_offset = 0.0
        self._k_factor = 6.6  # YF-B6 K-factor from spec
        self._liter_acc = 0.0
        self._total_pulses = 0
        self._hw_offset = 0
        self._raw_counter_last = 0
        self.flow = 0.0
        self.total_liter = 0.0
        self.total_liter_last = 0.0
        self.total_pulses_last = 0

        var current_counter = gpio.counter_read(self.__index)
        if current_counter != nil
            self.total_pulses_last = current_counter
            self._total_pulses = current_counter
            self._raw_counter_last = current_counter
        end
    end

    # Constructor
    def init(index, name)
        self.__index = index
        self.__name = name

        self._init()
    end

    # Load from persist
    def load()
        var result = false
        var prefix = "wc_" + str(self.__index)

        if persist.has(prefix + "_pulses")
            result = true
            self._initial_offset = persist.find(prefix + "_offset")
            self._k_factor = persist.find(prefix + "_kfactor", 6.6)
            self._total_pulses = persist.find(prefix + "_pulses")
            self.total_liter = persist.find(prefix + "_liter")

            self._liter_acc = self.total_liter - self._initial_offset

            log("Loaded Water Counter " + self.__name + ": Pulses=" + str(self._total_pulses) +
                ", Total Liter=" + string.format("%.2f", self.total_liter) +
                ", Offset=" + string.format("%.2f", self._initial_offset) +
                ", K-Factor=" + string.format("%.2f", self._k_factor))
        end

        self._sync_hw_alignment()

        return result
    end

    # Align logical counter with current hardware value (handles Tasmota rollback)
    def _sync_hw_alignment()
        var current_counter = gpio.counter_read(self.__index)

        if current_counter == nil
            return
        end

        self._raw_counter_last = current_counter

        if self._total_pulses >= current_counter
            self._hw_offset = self._total_pulses - current_counter
        else
            # Hardware counter is ahead of persisted value (unexpected). Adopt hardware and align liters.
            var delta_pulses = current_counter - self._total_pulses
            if delta_pulses > 0
                var delta_liters = delta_pulses / (self._k_factor * 60.0)
                self.total_liter_last = self.total_liter
                self._liter_acc += delta_liters
                self.total_liter = self._initial_offset + self._liter_acc
            end

            self._hw_offset = 0
            self.total_pulses_last = current_counter
            self._total_pulses = current_counter
        end
    end

    # Save to persist
    def save()
        var prefix = "wc_" + str(self.__index)

        persist.setmember(prefix + "_offset", self._initial_offset)
        persist.setmember(prefix + "_kfactor", self._k_factor)
        persist.setmember(prefix + "_pulses", self._total_pulses)
        persist.setmember(prefix + "_liter", self.total_liter)

        log("Saved Water Counter " + self.__name, 3)
    end

    # Capture current counter value and compute delta
    def capture()
        var current_counter = gpio.counter_read(self.__index)

        if current_counter != nil
            if current_counter < self._raw_counter_last
                var previous_total = self._total_pulses
                self._hw_offset = previous_total - current_counter
                log(string.format("Detected counter rollback on %s (raw %d -> %d), applying offset %d",
                    self.__name, self._raw_counter_last, current_counter, self._hw_offset), 2)
            end

            self._raw_counter_last = current_counter

            var logical_counter = current_counter + self._hw_offset
            self._delta = logical_counter - self._total_pulses

            if self._delta < 0
                log(string.format("Warning: negative delta on %s (logical=%d, tracked=%d)",
                    self.__name, logical_counter, self._total_pulses))
                self._delta = 0
            end

            self.total_pulses_last = self._total_pulses
            self._total_pulses = logical_counter
        end
    end

    # Update flow and totals (called every 100ms like original Tasmota script)
    # YF-B6 Spec: Q [L/min] = fpulse[Hz] / K where K=6.6
    # delta = pulses in 100ms (0.1s)
    # Frequency = delta / 0.1s = delta * 10 Hz
    # Flow = (delta * 10) / K L/min
    def update()
        # Calculate flow rate: convert delta (pulses/100ms) to L/min
        # f[Hz] = delta * 10, Q[L/min] = f / K = (delta * 10) / K
        self.flow = (self._delta * 10.0) / self._k_factor

        # Update accumulated liters: 1 liter = K * 60 pulses
        var delta_liters = self._delta / (self._k_factor * 60.0)
        self._liter_acc += delta_liters

        self.total_liter_last = self.total_liter
        self.total_liter = self._initial_offset + self._liter_acc

        # Reset delta to prevent double counting
        self._delta = 0
    end

    # Reset counter
    def reset()
        log("Reset Water Counter " + self.__name)

        gpio.counter_set(self.__index, 0)
        self._init()
    end

    # Set offset calibration
    def _set_offset(target_value)
        self._initial_offset = target_value - self._liter_acc

        self.total_liter = self._initial_offset + self._liter_acc
    end

    def get_offset()
        return self._initial_offset
    end

    # Get K-factor (public getter)
    def get_k_factor()
        return self._k_factor
    end

    # Set K-factor (public setter)
    def set_k_factor(value)
        var result = false

        log("Setting K-factor for " + self.__name + " to " + string.format("%.2f", value))

        if value > 0
            self._k_factor = value
            result = true
        else
            log(string.format("Error: K-factor must be > 0 (got %.2f)", value))
        end

        return result
    end
end

class WaterCounter
    var _counters            # List of Counter instances
    var _debounce_ms         # Counter debounce in milliseconds

    var _flow_cold           # Calculated cold flow rate
    var _flow_start_time     # Time when flow started (for duration tracking)
    var _last_save           # Last save timestamp (daily)
    var _last_use_datetime   # Last water usage datetime (when flow stopped)
    var _total_liter_cold    # Calculated cold total
    var _was_flowing         # Track if water was flowing in previous cycle
    var _in_flowing         # Flag to force MQTT report on next update (e.g. after config change)
    var _topic               # MQTT topic for publishing results
    var _last_published_time  # Last time MQTT data was published (for rate limiting if needed)
    var _config_fragment_cache  # Cached config JSON fragment

    # Initialize calculated values
    def _init()
        self._debounce_ms = 3  # Default debounce value
        self._flow_cold = 0.0
        self._flow_start_time = 0
        self._last_save = tasmota.millis()
        self._last_use_datetime = "Never"
        self._total_liter_cold = 0.0
        self._was_flowing = false
        #self._discovery_published = false  # Track if discovery was published
        self._in_flowing = false
        self._last_published_time = tasmota.millis()

        self._topic = self._get_topic()
    end

    # Constructor
    def init()
        log("Initializing Water Counter module...")
        self._init()

        # Initialize counters
        self._counters = [
            Counter(0, "Global"),
            Counter(1, "Hot")
        ]

        # Load persistent data
        self._load_persistent()

        # Set counter debounce AFTER loading config
        self._apply_debounce()

        # Register as Tasmota driver
        # mqtt_data() will be called automatically when MQTT messages arrive
        tasmota.add_driver(self)
    end

    # Load CounterDebounce from persist or use default 3ms
    # YF-B6 at 30 L/min max produces pulses every 5ms (198 Hz)
    # Debounce must be < 5ms to count all pulses
    def _apply_debounce()
        log("Setting counter debounce...")
        tasmota.cmd(string.format("CounterDebounce %d", self._debounce_ms))
    end

    # Load persistent data
    def _load_persistent()
        var loaded = false

        log("Loading persistent data for Water Counter...")
        for counter : self._counters
            loaded = counter.load() || loaded
        end

        # Load last use datetime
        if persist.has("wc_last_use")
            self._last_use_datetime = persist.find("wc_last_use")
        end

        # Load debounce setting (default 3 if not found)
        self._debounce_ms = persist.find("wc_debounce", 3)

        # If nothing was loaded, save defaults
        if !loaded
            self._save_persistent()
        end

        # Build config fragment cache after loading
        self._refresh_config_cache()
    end

    # Save persistent data
    def _save_persistent()
        log("Saving persistent data for Water Counter...")

        for counter : self._counters
            counter.save()
        end

        # Save last use datetime
        persist.setmember("wc_last_use", self._last_use_datetime)

        # Save debounce setting
        persist.setmember("wc_debounce", self._debounce_ms)

        persist.save()

        self._last_save = tasmota.millis()
    end

    # Register web handlers at the right time
    def web_add_handler()
        log("Registering Water Counter web handlers...")
        webserver.on("/wc_config", / -> self.web_config_handler(), webserver.HTTP_GET)
        webserver.on("/wc_set", / -> self.web_set_handler(), webserver.HTTP_POST)
    end

    # Publish Tasmota discovery for custom sensors
    # Must be called when MQTT connects to register sensors with HA
    # def _publish_tasmota_discovery()
    #     if !mqtt.connected()
    #         return
    #     end

    #     import json
    #     var mac = tasmota.wifi()['mac']
    #     var device_id = string.tr(mac, ':', '')  # Remove colons for ID

    #     # Define sensors configuration with metadata for HA auto-discovery
    #     # Each sensor needs: name (n), unit (u), state_class (sc), device_class (dc)
    #     var sensors = {
    #         "WaterCounter": {
    #             "Global": {
    #                 "Total": {
    #                     "n": "Global Total Water",
    #                     "u": "L",
    #                     "sc": "total_increasing",
    #                     "dc": "water"
    #                 },
    #                 "Flow": {
    #                     "n": "Global Flow Rate",
    #                     "u": "L/min",
    #                     "sc": "measurement",
    #                     "dc": "volume_flow_rate"
    #                 }
    #             },
    #             "Hot": {
    #                 "Total": {
    #                     "n": "Hot Total Water",
    #                     "u": "L",
    #                     "sc": "total_increasing",
    #                     "dc": "water"
    #                 },
    #                 "Flow": {
    #                     "n": "Hot Flow Rate",
    #                     "u": "L/min",
    #                     "sc": "measurement",
    #                     "dc": "volume_flow_rate"
    #                 }
    #             },
    #             "Cold": {
    #                 "Total": {
    #                     "n": "Cold Total Water",
    #                     "u": "L",
    #                     "sc": "total_increasing",
    #                     "dc": "water"
    #                 },
    #                 "Flow": {
    #                     "n": "Cold Flow Rate",
    #                     "u": "L/min",
    #                     "sc": "measurement",
    #                     "dc": "volume_flow_rate"
    #                 }
    #             }
    #         }
    #     }

    #     # Publish to Tasmota discovery topic with metadata wrapper
    #     var discovery_topic = string.format("tasmota/discovery/%s/sensors", device_id)
    #     var discovery_msg = {"sn": sensors, "ver": 1}
    #     var config_json = json.dump(discovery_msg)

    #     # Disabled overide
    #     #mqtt.publish(discovery_topic, config_json, true)  # retained = true
    #     log("Published Tasmota discovery configuration", 2)
    # end

    # MQTT driver method: called when MQTT messages arrive
    # Use to detect MQTT connection and publish discovery
    # var _discovery_published

    def _get_topic()
        return string.replace(string.replace(
                    tasmota.cmd('_FullTopic',true)['FullTopic'],
                        '%topic%', tasmota.cmd('_Topic',true)['Topic']),
                        '%prefix%', tasmota.cmd('_Prefix',true)['Prefix3'])
                + 'SENSOR'
    end

    def _refresh_config_cache()
        var global = self._counters[0]
        var hot = self._counters[1]

        self._config_fragment_cache = string.format(
            '"Config":{"DebounceMs":%d,'..
            '"Global":{"Offset":%.2f,"KFactor":%.2f},'..
            '"Hot":{"Offset":%.2f,"KFactor":%.2f}}',
            self._debounce_ms,
            global.get_offset(),
            global.get_k_factor(),
            hot.get_offset(),
            hot.get_k_factor()
        )
    end

    def _mqtt_build_payload_full(time, glb_cnt, hot_cnt, glb_total, glb_flow, hot_total, hot_flow, cold_total, cold_flow)
        return string.format(
            '{"Time":"%s",'..
            '"COUNTER":{"C1":%d,"C2":%d},'..
            '"WaterCounter":{'..
                '"Global":{"Total":%.2f,"Flow":%.3f},'..
                '"Hot":{"Total":%.2f,"Flow":%.3f},'..
                '"Cold":{"Total":%.2f,"Flow":%.3f},'..
                '%s'..
            '}}',
            time,
            glb_cnt,
            hot_cnt,
            glb_total,
            glb_flow,
            hot_total,
            hot_flow,
            cold_total,
            cold_flow,
            self._config_fragment_cache
        )
    end

    def _mqtt_publish(time, glb_cnt, hot_cnt, glb_total, glb_flow, hot_total, hot_flow, cold_total, cold_flow)
        if ((self._last_published_time + 500) > tasmota.millis() || glb_flow == 0.0 || hot_flow == 0.0)

            var _sensor_json = self._mqtt_build_payload_full(
                time,
                glb_cnt,
                hot_cnt,
                glb_total,
                glb_flow,
                hot_total,
                hot_flow,
                cold_total,
                cold_flow
            )

            mqtt.publish(self._topic, _sensor_json)
            self._last_published_time = tasmota.millis()
        end
    end

    # def mqtt_data(topic, idx, payload_s, payload_b)
    #     # Publish discovery config once when MQTT is connected
    #     if !self._discovery_published && mqtt.connected()
    #         self._discovery_published = true
    #         self._publish_tasmota_discovery()
    #     end
    #     return nil  # Let other handlers process MQTT messages
    # end

    def _report_stat()
        var _is_flowing =
            (self._counters[0].total_liter != self._counters[0].total_liter_last) ||
            (self._counters[1].total_liter != self._counters[1].total_liter_last)
            # (self._counters[0].flow > 0.001) || (self._counters[1].flow > 0.001)

        var time = tasmota.cmd('_Time', true)['Time']
        var _time_ms = string.split(time, '.')
        var time_before = _time_ms[0] + "." + string.format("%03d", (int(_time_ms[1]) - 10) % 1000)
        var time_after = _time_ms[0] + "." + string.format("%03d", (int(_time_ms[1]) + 10) % 1000)

        if (_is_flowing)
            if (!self._in_flowing)
                log("Flow started, pushing initial state...")

                # Push initial state when flow starts (to capture starting point with offset)
                self._mqtt_publish(
                    time_before,
                    self._counters[0].total_pulses_last,
                    self._counters[1].total_pulses_last,
                    self._counters[0].total_liter_last,
                    0.0,
                    self._counters[1].total_liter_last,
                    0.0,
                    self._counters[0].total_liter_last - self._counters[1].total_liter_last,
                    0.0
                )

                self._in_flowing = true
            end

            # Push current state while flowing (every 100ms)
            self._mqtt_publish(
                time,
                self._counters[0]._total_pulses,
                self._counters[1]._total_pulses,
                self._counters[0].total_liter,
                self._counters[0].flow,
                self._counters[1].total_liter,
                self._counters[1].flow,
                self._total_liter_cold,
                self._flow_cold
            )

        else
            if (self._in_flowing)
                log("Flow stopped, pushing final state...")

                # Push final state when flow stops (to capture stopping point)
                self._mqtt_publish(
                    time_after,
                    self._counters[0]._total_pulses,
                    self._counters[1]._total_pulses,
                    self._counters[0].total_liter,
                    0.0,
                    self._counters[1].total_liter,
                    0.0,
                    self._total_liter_cold,
                    0.0
                )

                self._in_flowing = false
            end
        end

    end

    # Called every 100ms (like original Tasmota script for better flow precision)
    def every_100ms()
        # Capture and update counters every 100ms (sync with Tasmota sampling)
        for counter : self._counters
            counter.capture()
        end

        for counter : self._counters
            counter.update()
        end

        # Calculate cold water (Global - Hot)
        self._total_liter_cold = self._counters[0].total_liter - self._counters[1].total_liter
        self._flow_cold = self._counters[0].flow - self._counters[1].flow

        self._report_stat()
    end

    # Called every second for state management
    def every_second()
        var now = tasmota.millis()

        # Detect flow stop (was flowing, now stopped)
        var is_flowing = (self._counters[0].flow > 0.001) || (self._counters[1].flow > 0.001)

        # Track flow start time
        if !self._was_flowing && is_flowing
            self._flow_start_time = now
            log("Flow started")
        end

        if self._was_flowing && !is_flowing
            # Water just stopped flowing - capture datetime and duration
            var rtc = tasmota.rtc()
            var dt = tasmota.time_dump(rtc['local'])
            self._last_use_datetime = string.format("%04d-%02d-%02d %02d:%02d:%02d",
                dt['year'], dt['month'], dt['day'], dt['hour'], dt['min'], dt['sec'])
            var duration_sec = (now - self._flow_start_time) / 1000.0

            log(string.format("Flow stopped. Duration: %.1f seconds. Last use: %s", duration_sec, self._last_use_datetime))

            # Persist totals immediately after each use to guard against unexpected reboots
            self._save_persistent()
        end
        self._was_flowing = is_flowing

        # Save persistent variables once a day (86400000 ms = 24 hours)
        if (now - self._last_save) >= 86400000
            self._save_persistent()
        end
    end

    # Called before restart to save persistent data
    def save_before_restart()
        log("Saving Water Counter data before restart...")
        self._save_persistent()
    end

    # Tasmota driver method: Add sensor data to TelePeriod JSON
    # Called automatically by Tasmota at each TelePeriod (or Status 8)
    def json_append()
        if !mqtt.connected()
            return
        end

        var global = self._counters[0]
        var hot = self._counters[1]

        # Log to console for debugging
        log(string.format("Water: Global: %.2f l (%.3f l/min), Hot: %.2f l (%.3f l/min), Cold: %.2f l (%.3f l/min)",
            global.total_liter, global.flow, hot.total_liter, hot.flow, self._total_liter_cold, self._flow_cold), 3)

        # Build JSON fragment for SENSOR data (Tasmota standard format)
        # This will be published to tele/%topic%/SENSOR automatically
        var json_data = string.format(
            ',"WaterCounter":{'
            '"Global":{"Total":%.2f,"Flow":%.3f},'
            '"Hot":{"Total":%.2f,"Flow":%.3f},'
            '"Cold":{"Total":%.2f,"Flow":%.3f},'
            '%s'..
            '},"FlowUnit":"L/min","TotalUnit":"L"',
            global.total_liter, global.flow,
            hot.total_liter, hot.flow,
            self._total_liter_cold, self._flow_cold,
            self._config_fragment_cache
        )

        # Append to Tasmota's telemetry JSON
        # Will be automatically published to tele/%topic%/SENSOR
        tasmota.response_append(json_data)
    end

    # Reset all counters
    def _reset()
        log("Resetting all Water Counters...")

        for counter : self._counters
            counter.reset()
        end

        self._init()
        self._save_persistent()
    end

    # Display on web UI
    def web_sensor()
        var global = self._counters[0]
        var hot = self._counters[1]

        var msg = string.format(
            "{s}Global Total{m}%.2f l{e}"..
            "{s}Global Flow{m}%.3f l/min{e}"..
            "{s}Global Offset{m}%.2f l{e}"..
            "{s}Global K-Factor{m}%.2f{e}"..
            "{s}Hot Total{m}%.2f l{e}"..
            "{s}Hot Flow{m}%.3f l/min{e}"..
            "{s}Hot Offset{m}%.2f l{e}"..
            "{s}Hot K-Factor{m}%.2f{e}"..
            "{s}Cold Total{m}%.2f l{e}"..
            "{s}Cold Flow{m}%.3f l/min{e}"..
            "{s}Debounce{m}%d ms{e}"..
            "{s}Last Use{m}%s{e}",
            global.total_liter,
            global.flow,
            global.get_offset(),
            global.get_k_factor(),
            hot.total_liter,
            hot.flow,
            hot.get_offset(),
            hot.get_k_factor(),
            self._total_liter_cold,
            self._flow_cold,
            self._debounce_ms,
            self._last_use_datetime)

        webserver.content_send(msg)
    end

    # Add button to main web page
    def web_add_main_button()
        log("Adding Water Counter button to main web page...", 3)
        webserver.content_send("<p><form action='/wc_config' method='get'><button>Water Counter Config</button></form></p>")
    end

    # Web configuration page handler
    def web_config_handler()
        if !webserver.check_privileged_access()
            return
        end
        log("Handling Water Counter configuration page request...", 3)

        var global = self._counters[0]
        var hot = self._counters[1]

        webserver.content_start("Water Counter Configuration")
        webserver.content_send_style()

        # Current Status
        webserver.content_send("<fieldset><legend><b>&nbsp;Current Status&nbsp;</b></legend>")
        webserver.content_send(string.format("<p>Global: %.2f l (%.3f l/min)</p>", global.total_liter, global.flow))
        webserver.content_send(string.format("<p>Hot: %.2f l (%.3f l/min)</p>", hot.total_liter, hot.flow))
        webserver.content_send(string.format("<p>Cold: %.2f l (%.3f l/min)</p>", self._total_liter_cold, self._flow_cold))
        webserver.content_send(string.format("<p>Last Use: %s</p>", self._last_use_datetime))
        webserver.content_send("</fieldset>")

        webserver.content_send("<form method='post' action='/wc_set'>")

        # Helper to create counter config fields
        def counter_fields(idx, label, counter)
            var k = counter.get_k_factor()
            var ppl = k * 60.0  # PPL = K-factor × 60
            webserver.content_send(string.format("<fieldset><legend><b>&nbsp;%s Counter&nbsp;</b></legend>", label))
            webserver.content_send(string.format("<p><label>Target Offset (l):</label><input type='number' step='0.01' name='offset%d' value='%.2f'></p>", idx, counter.total_liter))
            webserver.content_send(string.format("<p><button type='submit' name='action' value='set_offset%d'>Apply %s Offset</button></p>", idx, label))
            webserver.content_send(string.format("<p><label>K-Factor:</label><input type='number' step='0.01' name='kfactor%d' value='%.2f'></p>", idx, k))
            webserver.content_send(string.format("<p style='margin-left:20px;'><small>→ %.0f pulses/liter</small></p>", ppl))
            webserver.content_send(string.format("<p><button type='submit' name='action' value='set_kfactor%d'>Apply %s K-Factor</button></p>", idx, label))
            webserver.content_send("</fieldset>")
        end

        counter_fields(1, "Global", global)
        counter_fields(2, "Hot Water", hot)

        # Counter debounce configuration
        webserver.content_send("<fieldset><legend><b>&nbsp;Advanced Settings&nbsp;</b></legend>")
        webserver.content_send(string.format("<p><label>Counter Debounce (ms):</label><input type='number' step='1' min='0' max='10' name='debounce' value='%d'></p>", self._debounce_ms))
        webserver.content_send("<p style='margin-left:20px;'><small>Recommended: 2-3 ms for YF-B6 (max 30 L/min = 5ms period)</small></p>")
        webserver.content_send("<p><button type='submit' name='action' value='set_debounce'>Apply Debounce</button></p>")
        webserver.content_send("</fieldset>")

        # Reset button
        webserver.content_send("<p><button type='submit' name='action' value='reset' style='background-color:#d43535;'>Reset All Counters</button></p>")

        webserver.content_send("</form>")
        webserver.content_button(webserver.BUTTON_MAIN)
        webserver.content_stop()
    end

    # Handle web form submission
    def web_set_handler()
        if !webserver.check_privileged_access()
            return
        end

        var action = webserver.arg("action")
        var msg = "Settings updated!"

        try
            # Parse action and apply changes
            if action == "set_offset1"
                var value = real(webserver.arg("offset1"))
                self._counters[0]._set_offset(value)
                self._save_persistent()
                self._refresh_config_cache()
                msg = string.format("Global offset set to %.2f l", self._counters[0]._initial_offset)
            elif action == "set_offset2"
                var value = real(webserver.arg("offset2"))
                self._counters[1]._set_offset(value)
                self._save_persistent()
                self._refresh_config_cache()
                msg = string.format("Hot offset set to %.2f l", self._counters[1]._initial_offset)
            elif action == "set_kfactor1"
                var value = real(webserver.arg("kfactor1"))
                if self._counters[0].set_k_factor(value)
                    self._save_persistent()
                    self._refresh_config_cache()
                    msg = string.format("Global K-Factor set to %.2f", value)
                else
                    msg = string.format("Error: Invalid PPL value %.2f (must be > 0)", value)
                end
            elif action == "set_kfactor2"
                var value = real(webserver.arg("kfactor2"))
                if self._counters[1].set_k_factor(value)
                    self._save_persistent()
                    self._refresh_config_cache()
                    msg = string.format("Hot K-Factor set to %.2f", value)
                else
                    msg = string.format("Error: Invalid K-Factor value %.2f (must be > 0)", value)
                end
            elif action == "set_debounce"
                var value = int(webserver.arg("debounce"))
                if value >= 0 && value <= 10
                    self._debounce_ms = value
                    self._apply_debounce()
                    self._save_persistent()
                    self._refresh_config_cache()
                    msg = string.format("Counter Debounce set to %d ms", value)
                else
                    msg = string.format("Error: Debounce must be 0-10 ms (got %d)", value)
                end
            elif action == "reset"
                self._reset()
                msg = "All counters reset!"
            else
                msg = "Unknown action: " + str(action)
            end
            log(msg)
        except .. as e, m
            msg = "Error: " + str(m)
            log("Water Counter error: " + str(m))
        end

        # Send response page
        webserver.content_start("Water Counter")
        webserver.content_send_style()
        webserver.content_send("<div style='text-align:center;padding:20px;'>")
        webserver.content_send(string.format("<h2>%s</h2>", msg))
        webserver.content_send("<p><a href='/wc_config'><button>Back to Configuration</button></a></p>")
        webserver.content_send("<p><a href='/'><button>Main Page</button></a></p>")
        webserver.content_send("</div>")
        webserver.content_stop()
    end
end

# Create and initialize the water counter
water_counter = WaterCounter()
