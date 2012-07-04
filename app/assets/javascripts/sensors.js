(function() {

  window.Sensors || (window.Sensors = {});

  var charts = {};

  Sensors.init = function(source) {
    $("#graphs-loaded").html((new Date()).format());
    $(".sensor_suffix").html(sensor['suffix']);
    $("." + source).html(reading['reading']);
    draw_chart($('#hourly_chart')[0], 'hour', source, null);
    draw_chart($('#daily_chart')[0], 'day', source, null);
  }

  function draw_chart(target, dimension, source, title) {
    title = typeof title == 'undefined' ? dimension : title;
    chart = new Mini_Chart(target, title);
    chart.plot( ( sources[source]['monitor_type']=="gauge" ? Data.get_gauge_series_set(dimension, source) : Data.get_meter_series_set(dimension, source) ) );
  }


}).call(this); 
