ruleset com.blacklite.krl.manage_sensors {
 meta {
   shares __testing, showChildren, sensors, temperatures, getSensorNameFromTx, report

   use module io.picolabs.wrangler alias wrangler
   use module io.picolabs.subscription alias subscription
 }
 global {
   __testing = { "queries":
     [ { "name": "__testing" }
     , { "name": "showChildren" }
     , { "name": "sensors" }
    // , { "name": "temperatures" }
     , { "name": "report" }
     , { "name": "getSensorNameFromTx", "args": ["Tx"] }
     ] , "events":
     [ { "domain": "sensor", "type": "new_sensor", "attrs": [ "name" ] }
     , { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "name" ] }
     , { "domain": "sensor", "type": "subscribe", "attrs": [ "name", "eci"] }
     , { "domain": "sensor", "type": "report_requested" }
     ]
   }

   showChildren = function() {
     wrangler:children()
   }

   sensors = function() {
     sensor_subscriptions = subscription:established().filter(function(x) {
       x{"Tx_role"} == "sensor"
     });
     sensor_subscriptions
   }
   
   getSensorFromTx = function(Tx) {
     subscription:established().filter(function(x) {
       x{"Tx"} == Tx
     })[0]
   }

   getSensorNameFromTx = function(Tx) {
     ent:sensors.filter(function(v,k) {
       v == Tx
     }).keys().decode()
   }
   
   report = function() {
     sortedKeys = ent:report.keys().sort("reverse")
     last5 = sortedKeys.length() > 5 => sortedKeys.slice(0,4) | sortedKeys
     ent:report.filter(function(v,k) {
       last5.any(function(x) { x == k})
     })
   }

  // temperatures = function(child) {
  //   sensors().map(function(x) {
  //     eci = x.get("Tx");
  //     url = "http://localhost:8080/sky/cloud/" + eci + "/com.blacklite.krl.temperature_store/temperatures";
  //     response = http:get(url);
  //     sensor_name = getSensorNameFromTx(eci);
  //     temperatures = response{"content"}.decode();
  //     {}.put(sensor_name, temperatures)
  //   })
  // }
 }

 rule add_sensor {
   select when sensor new_sensor
   pre {
     name = event:attr("name")
     exists = ent:sensors >< name
     eci = meta:eci
   }
   if exists then
     send_directive("new_sensor", {"status":"not added", "message":"this sensor already exists"})
   notfired {
     raise wrangler event "child_creation"
       attributes {
         "name": name,
         "color": "#bbbbbb",
         "type": "sensor",
         "rids": [
           "com.blacklite.krl.temperature_store",
           "com.blacklite.krl.wovyn_base",
           "com.blacklite.krl.sensor_profile"
           ]
       }
   }
 }

 rule child_sensor_auto_subscribe {
   select when wrangler child_initialized
   pre {
     is_sensor = (event:attrs{"type"} == "sensor")
     sensor_name = event:attr("name")
     sensor_eci = event:attr("eci")
   }

   if is_sensor then
   every {
     event:send(
       { "eci": meta:eci, "eid": "subscription",
       "domain": "wrangler", "type": "subscription",
       "attrs": { "name": sensor_name,
                  "Rx_role": "controller",
                  "Tx_role": "sensor",
                  "channel_type": "subscription",
                  "wellKnown_Tx": sensor_eci }
       });
     event:send(
       {
         "eci": sensor_eci, "eid": "update_profile",
         "domain": "sensor", "type": "profile_updated",
         "attrs": { "name": sensor_name }
       })
   }
 }

 rule add_sensor_subscription {
   select when sensor subscribe
   pre {
     sensor_name = event:attr("name")
     sensor_eci = event:attr("eci")
   }

   if sensor_name && sensor_eci then
    event:send(
     { "eci": meta:eci, "eid": "subscription",
       "domain": "wrangler", "type": "subscription",
       "attrs": { "name": sensor_name,
                  "Rx_role": "controller",
                  "Tx_role": "sensor",
                  "channel_type": "subscription",
                  "wellKnown_Tx": sensor_eci }
     })
 }
 rule map_sensor_subscription {
   select when wrangler subscription_added
   pre {
     is_sensor_subscription = event:attr("Rx_role") == "sensor"
     sensor_name = event:attr("name");
     subscription_eci = event:attr("Rx")
   }

   if is_sensor_subscription then noop()

   fired {
     ent:sensors := ent:sensors.defaultsTo({});
     ent:sensors{[sensor_name]} := subscription_eci;
   }
 }

 rule delete_sensor {
   select when sensor unneeded_sensor
   pre {
     sensor_name = event:attrs{"name"}
     exists = ent:sensors >< sensor_name
   }

   if exists then
     event:send(
       {
         "eci": ent:sensors{[sensor_name]}.klog("eci to subscription"),
         "eid": "removing_subscriptions",
         "domain": "sensor", "type": "remove_subscriptions"
       })

   fired {
     raise wrangler event "child_deletion"
       attributes {"name": sensor_name};
   }
 }

 rule remove_stored_sensor {
   select when wrangler delete_child
   pre {
     sensor_name = event:attrs{"name"}
   }

   if sensor_name.klog("sensor to delete: ") then noop()

   fired {
     ent:sensors := ent:sensors.delete([sensor_name])
   }
 }
 
 rule create_report_id {
   select when sensor report_requested 
   pre {
     coid = time:now();
   }
   fired {
     raise report event "requested" attributes { "coid": coid }
   }
 }
 rule request_temperature_report {
   select when report requested
   foreach sensors() setting (sensor)
   pre {
     eci = sensor{"Tx"};
     originatorEci = sensor{"Rx"};
     coid = event:attr("coid")
   }
   event:send({
     "eci": eci, "eid": "temperature_report",
     "domain": "sensor", "type": "report_requested",
     "attrs": { "reportId": coid, "originatorEci" : originatorEci }
   })
   fired {
     
   }
 }
 
 rule collect_temperature_report {
   select when report delivered
   pre {
     report = event:attr("report");
     sensor = getSensorFromTx(event:attr("sensorEci"));
     coid = event:attr("reportId");
   }
   if (coid && report && sensor) then noop()
   fired {
     ent:report{[coid, sensor{"Id"}]} := report
     ent:report{[coid, "count"]} := ent:report{[coid, "count"]}.defaultsTo(0) + 1
     ent:report{[coid, "time_of_report"]} := time:strftime(coid, "%c")
   }
 }
}


