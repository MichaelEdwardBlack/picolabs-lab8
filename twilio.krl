ruleset com.blacklite.krl.twilio {
  meta {
    name "Twilio Module"
    use module com.blacklite.krl.twilio.key
    use module com.blacklite.krl.twilio.sms alias sms
      with account_sid = keys:twilioKeys{"account_sid"}
           auth_token = keys:twilioKeys{"auth_token"}

    shares __testing, messages
  }

  global {
    messages = function(messageID, to, from) {
      sms:get_messages(messageID, to, from)
    }
    __testing = {
      "queries":[ {"name": "messages", "args": ["messageID", "to", "from"]} ],
      "events": [ {"domain": "twilio", "type": "send_message", "attrs": ["to", "from", "message"]} ]
    }
  }

  rule test_send_sms {
    select when twilio send_message
    sms:send_sms(event:attr("to"),
             event:attr("from"),
             event:attr("message")
             )
  }
}
