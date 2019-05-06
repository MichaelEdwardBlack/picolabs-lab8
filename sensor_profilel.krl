ruleset com.blacklite.krl.sensor_profile {
  meta {
    name "Sensor Profile"
    author "Michael Black"
    shares get_profile, __testing
    use module com.blacklite.krl.temperature_store alias tempStore
    use module io.picolabs.subscription alias subscription
  }
  global {
    get_profile = function() {
      { "name": ent:name.defaultsTo("First Sensor"),
        "location": ent:location.defaultsTo("Timbuktu"),
        "contact": ent:contact.defaultsTo("17195390627"),
        "threshold": ent:threshold.defaultsTo(90) }
    }

    get_color = function() {
      temperatures = tempStore:temperatures().values();
      last_temp_recording = temperatures[temperatures.length() - 1].klog("last recording");
      (last_temp_recording == null) => "#bbbbbb" |
      (last_temp_recording <= 0) => "#0000ff" |
      (last_temp_recording <= 32) => "#00bbff" |
      (last_temp_recording <= 62) => "#00ffff" |
      (last_temp_recording <= 80) => "#00ff66" |
      (last_temp_recording <= 90) => "#ffcc00" |
      (last_temp_recording <= 110) => "#ff6600" | "#ff0000"

    }
    __testing = { "queries":
      [ { "name": "__testing" },
        { "name": "get_profile"}
      ] , "events":
      [ { "domain": "sensor", "type": "profile_updated",
                              "attrs": ["name", "location", "send_to", "threshold"]}
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
  }

  rule update_profile {
    select when sensor profile_updated

    noop()

    fired {
      ent:name := event:attr("name") || ent:name || "First Sensor";
      ent:location := event:attr("location") || ent:location || "Timbuktu";
      ent:contact := event:attr("send_to") || ent:contact || "17193580627";
      ent:threshold := event:attr("threshold") || ent:threshold || 90;

      raise wovyn event "set_threshold"
        attributes {"threshold": ent:threshold};

      raise visual event "update"
        attributes {"dname": event:attr("name") || ent:name, "color": get_color()}
    }
  }

  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }

  rule remove_subscriptions {
    select when sensor remove_subscriptions
    foreach subscription:established() setting(subcription)

    always {
      raise wrangler event "subcription_cancellation"
        attributes {"Tx":subscription{"Tx"}};
      raise wrangler event "subscription_cancellation"
        attributes {"Tx":subscription{"Rx"}}
    }
  }
}
