(function() {

  window.WebSocketListener || (window.WebSocketListener = {});

  socket = new WebSocket('ws://ec2-50-19-129-102.compute-1.amazonaws.com:8081');

  socket.onmessage = function(mess) {
    payload = $.parseJSON(mess.data);
    $("#murmur").html(payload["source"] + ": " + mess.data);
    process_message(payload);
    socket.send(payload['guid']);
  };

  socket.onerror = function() {
    $(".flash").show();
  }

  socket.onclose = function(close) {
    $(".flash").show();
  }

  function process_message(payload) {
    process_alarm(payload);
    process_basic_readings(payload);
    process_electricity(payload);
  }

  function process_basic_readings(payload) {
    if (payload["message_type"]=="reading") {
      $("." + payload["source"] + "_reading").html(payload["message"]);
    }
  }

  function process_alarm(payload) {
    if (payload["source"]=="alarm_armed") {
      $(".alarm_status").html(payload["message"]);
    }
  }

  function process_electricity(payload) {
    if (payload['message_type']=='dimensions') {
      if (payload["source"]=="electricity_total") {
        $('#electricity_total_day').html(payload['message']['day']['values']['sum']/1000);
        $('#electricity_total_week').html(payload['message']['week']['values']['sum']/1000);
        $('#electricity_total_month').html(payload['message']['month']['values']['sum']/1000);

        $.data( $('#electricity_total_day')[0], "wh", payload['message']['day']['values']['sum'] );
        $.data( $('#electricity_total_week')[0], "wh", payload['message']['week']['values']['sum'] );
        $.data( $('#electricity_total_month')[0], "wh", payload['message']['month']['values']['sum'] );
      }
      if ((payload["source"]=="electricity_pool") || (payload["source"]=="electricity_geyser")) {
        day = $.data( $('#electricity_total_day')[0], "wh" );
        if (day) {
          week  = $.data( $('#electricity_total_week')[0], "wh" );
          month = $.data( $('#electricity_total_month')[0], "wh" );

          day_percentage   = payload['message']['day']['values']['sum'] / day * 100;
          week_percentage  = payload['message']['week']['values']['sum'] / week * 100;
          month_percentage = payload['message']['month']['values']['sum'] / month * 100;

          source = payload["source"];

          $('#' + source + '_day').html(day_percentage);
          $('#' + source + '_week').html(week_percentage);
          $('#' + source + '_month').html(month_percentage);
        }
      }
    }
  }

}).call(this); 