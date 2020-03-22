ruleset com.blacklite.krl.temperature_store {
  meta {
    name "Temperature Store"
    author "Michael Black"

    provides temperatures, threshold_violations, inrange_temperatures

    shares __testing, temperatures, threshold_violations, inrange_temperatures
  }

  global {
    temperatures = function() {
      ent:temperature_readings
    }

    threshold_violations = function() {
      ent:temperature_violations
    }

    inrange_temperatures = function() {
      temperatures = ent:temperature_readings;
      violations = ent:temperature_violations;

      filtered_temps = temperatures.filter(function(v,k) {
        violations.get(k.klog("key: ")).klog("violation value: ").isnull()
      });

      filtered_temps
    }

    __testing = {
      "queries":[ {"name": "__testing"},
                  {"name": "temperatures"},
                  {"name": "threshold_violations"},
                  {"name": "inrange_temperatures"} ]
    }

  }

  rule guard_temperatures_map {
    select when wovyn new_temperature_reading

    if ent:temperature_readings.isnull() then noop();

    fired {
      ent:temperature_readings := {};
    }
  }

  rule collect_temperatures {
    select when wovyn new_temperature_reading

    pre {
      temperature = event:attrs{"temperature"}
      timestamp = event:attrs{"timestamp"}
    }

    if (not temperature.isnull() && not timestamp.isnull()) then noop()

    fired {
      ent:temperature_readings{timestamp} := temperature[0]{"temperatureF"}.decode();
      raise sensor event "profile_updated"
    }
  }

  rule guard_tempearture_violations_map {
    select when wovyn threshold_violation

    if ent:temperature_violations.isnull() then noop()

    fired {
      ent:temperature_violations := {};
    }
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation

    pre {
      tempF = event:attrs{"temperatureF"}
      timestamp = event:attrs{"timestamp"}
    }

    if (not tempF.isnull() && not timestamp.isnull()) then noop();

    fired {
      ent:temperature_violations{timestamp} := tempF;
    }
  }

  rule clear_temperatures {
    select when sensor reading_reset

    noop()

    fired {
      ent:temperature_readings := {};
      ent:temperature_violations := {};
    }
  }
  
  rule report_requested {
    select when sensor report_requested
    pre {
      originatorEci = event:attr("originatorEci");
      temperatures = temperatures();
      coid = event:attr("reportId");
    }
    event:send({
      "eci": originatorEci, "eid": "sensor_report",
      "domain": "report", "type": "delivered", 
      "attrs": { "reportId": coid, "report": temperatures, "sensorEci": meta:eci }
    })
  }
}
