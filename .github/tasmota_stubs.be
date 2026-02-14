#-
 * Tasmota Berry API Stubs for Syntax Validation
 * These stubs allow Berry compiler to validate syntax without actual Tasmota runtime
 * Only signatures are defined, no real implementation
 -#

# GPIO module - Hardware counter access
gpio = module("gpio")
gpio.counter_read = def(index) return 0 end
gpio.counter_set = def(index, value) end

# Persist module - Non-volatile storage
persist = module("persist")
persist.has = def(key) return false end
persist.find = def(key, default) return default end
persist.setmember = def(key, value) end
persist.save = def() end

# MQTT module - Message publishing
mqtt = module("mqtt")
mqtt.publish = def(topic, payload, retain) end
mqtt.connected = def() return true end

# Webserver module - HTTP handlers
webserver = module("webserver")
webserver.HTTP_GET = 0
webserver.HTTP_POST = 1
webserver.BUTTON_MAIN = 0
webserver.on = def(path, handler, method) end
webserver.has_arg = def(name) return false end
webserver.arg = def(name) return "" end
webserver.content_send = def(content) end
webserver.content_start = def(status) end
webserver.content_stop = def() end
webserver.content_send_style = def() end
webserver.content_button = def(button_type) end
webserver.check_privileged_access = def() return true end
webserver.content = def() return "" end

# Tasmota module - Core system functions
tasmota = module("tasmota")
tasmota.millis = def() return 0 end
tasmota.add_driver = def(driver) end
tasmota.cmd = def(command, get_result) return {} end
tasmota.wifi = def() return {"mac": "00:00:00:00:00:00"} end
tasmota.time_dump = def(timestamp) return {"year": 2026, "month": 1, "day": 1, "hour": 0, "min": 0, "sec": 0} end
tasmota.rtc = def() return {"local": 0, "utc": 0} end
tasmota.response_append = def(json_str) end

# Global log function
log = def(msg, level) end
