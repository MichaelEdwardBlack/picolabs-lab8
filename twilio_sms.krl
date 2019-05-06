ruleset com.blacklite.krl.twilio.sms {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides send_sms, get_messages
  }

  global {
    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
                "From":from,
                "To":to,
                "Body":message
            })
    }

    get_messages = function(messageID, to, from) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json>>;

      response = http:get(base_url, form = {
                "To":to,
                "From":from
                })["content"].decode()["messages"].decode();
      responseMap = response.map(function(x) {
        mid = x["sid"];
        to = x["to"];
        from = x["from"];
        body = x["body"];

        map = {"messageID":mid, "to": to, "from": from, "body": body};
        map
      });

      filterMessage = (messageID.isnull() || messageID == "") => responseMap | responseMap.filter(function(x) {
        x.get("messageID") == messageID;
      });

      toFilter = (to.isnull() || to == "") => filterMessage | filterMessage.filter(function(x) {
        x.get("to") == to;
      });

      result = (from.isnull() || from == "") => toFilter | toFilter.filter(function(x) {
        x.get("from") == from;
      });

      result
    }
  }
}
