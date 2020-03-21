ruleset com.blacklite.krl.twilio.key {
  meta {
    name "Twilio Key Module"
    key twilioKeys {
      "account_sid" : "<ACCOUNTSID>",
      "auth_token" : "<AUTHTOKEN>"
    }

    provide keys twilioKeys to com.blacklite.krl.twilio
  }
}
