ruleset com.blacklite.krl.manage_sensors.profile {
  meta {
    shares __testing
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "profile", "type": "contact_updated", "attrs": ["phone"] }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
  }

  rule update_contact_number {
    select when profile contact_updated

    pre {
      phone = event:attr("phone")
    }

    always {
      ent:contact := phone;
    }
  }

  rule threshold_violation {
   select when threshold violation_notification
   pre {
     sensorID = event:attr("sci")
     message = event:attr("message")
     temp = event:attr("temperature")
   }

   always {
     raise twilio event "send_message"
        attributes {"to": ent:contact.defaultsTo("+17193590627"),
                  "from": "+17193966763",
                  "message": message}
   }
 }
}
