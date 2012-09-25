(function() {

  window.Console || (window.Console = {});

  var charts = {};

  Console.overview = function(readings) {
    $("#graphs-loaded").html((new Date()).format());
    Templater.populate_template("sensor", readings, populate_sensor_template);
    poll();
    monitor();
  }

  Console.graphs = function(readings) {
    $("#graphs-loaded").html((new Date()).format());
    Templater.populate_template("graph", readings, populate_graph_template);
  }

  function populate_graph_template(template, index, value) {
    template.find('h2').html(sources[index]['name']);
    charts['5minute.' + index] = instantiate_chart(template, '5minute', index);
    charts['hour.' + index] = instantiate_chart(template, 'hour', index);
    charts['day.' + index] = instantiate_chart(template, 'day', index);
    charts['week.' + index] = instantiate_chart(template, 'week', index); 
    return template;
  }

  function instantiate_chart(template, dimension, source) {
    chart = new Mini_Chart(template.find('._' + dimension)[0], dimension);
    chart.plot( ( sources[source]['monitor_type']=="gauge" ? Data.get_gauge_series_set(dimension, source) : Data.get_meter_series_set(dimension, source) ) );
  }

  function populate_sensor_template(template, index, value) {
    name = ( sources[index] ? sources[index]['name'] : index );
    reading = value['reading'] + ( sources[index] && sources[index]['suffix'] ? sources[index]['suffix'] : '' )
    t = new Date(value['local_time']);
    var d = new Date();
    d.setDate(d.getDate() - 1);
    timeFormat = ( t > d ? "shortTime" : "mediumDateTime");
    template.children('.source').html(name);
    template.children('.reading').html( reading );
    template.find('.time').html( (t).format(timeFormat,true) ).data('expires', value['expires']);
    return template;
  }

  function monitor() {
    t = (new Date()).getTime();
    $('.expires').each(function(index, e) {
      expires = $(e).data('expires');
      if (expires) {
        if (expires < t) {
          $(e).addClass('label label-important');
        } else {
          $(e).removeClass('label label-important');
        }
      }
    });
    setTimeout(monitor, 2000);
  }

  function poll() {
    $.ajax({
      url: '/api/30_camp_ground_road/readings',
      dataType: 'json', 
      success: function(data) {
        Templater.populate_template('sensor', data, populate_sensor_template);
        e = $('#last_poll_time');
        e.html((new Date()).format());
        e.data('expires', (new Date()).getTime() + (60*1000) );
      },
      complete: function() {
        setTimeout(poll, 15000);
      }
    })
  };


}).call(this); 
