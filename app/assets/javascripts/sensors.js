(function() {

  window.Sensors || (window.Sensors = {});

  var charts = {};

  Sensors.init = function(source) {
    $("#graphs-loaded").html((new Date()).format());
    $(".sensor_suffix").html(sensor['suffix']);
    $("." + source).html(reading['reading']);
//    populate_template("graph", readings, populate_graph_template);
    format_fields();
    draw_chart($('#hourly_chart')[0], 'hour', source, null);
    draw_chart($('#daily_chart')[0], 'day', source, null);
  }

  function populate_template(singular_element_name, data_hash, templater) {
    target = $('#' + singular_element_name + 's');
    $.each(data_hash, function(name, value) {
      template = $('#' + '_' + singular_element_name + name);
      existing = (template.length!=0);
      if (!existing) {
        template = $('#' + singular_element_name + '_template').clone().attr('id', '_' + singular_element_name + name);
      }
      template = templater(template, name, value);
      if (!existing) {
        template.appendTo(target).show();
      } 
   });
  }

  function populate_graph_template(template, index, value) {
    template.find('h2').html(sources[index]['name']);
    charts['5minute.' + index] = instantiate_chart(template, '5minute', index);
    charts['hour.' + index] = instantiate_chart(template, 'hour', index);
    charts['day.' + index] = instantiate_chart(template, 'day', index);
    charts['week.' + index] = instantiate_chart(template, 'week', index); 
    return template;
  }

  function instantiate_chart_from_template(template, dimension, source) {
    draw_chart(template.find('._' + dimension)[0], dimension, source);
  }

  function draw_chart(target, dimension, source, title) {
    title = typeof title == 'undefined' ? dimension : title;
    chart = new Mini_Chart(target, title);
    chart.plot( ( sources[source]['monitor_type']=="gauge" ? get_gauge_series_set(dimension, source) : get_meter_series_set(dimension, source) ) );
  }

  function populate_sensor_template(template, index, value) {
    template.children('.source').html(sources[index]['name']);
    template.children('.reading').html( value['reading'] );
    template.find('.time').html( (new Date(value['local_time'])).format("shortTime",true) ).data('expires', value['expires']);
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
        populate_template('sensor', data, populate_sensor_template);
        e = $('#last_poll_time');
        e.html((new Date()).format());
        e.data('expires', (new Date()).getTime() + (60*1000) );
      },
      complete: function() {
        setTimeout(poll, 15000);
      }
    })
  };

  function get_gauge_series_set(dimension, source) {
    return [
           {
             name: 'max',
             data: get_chart_data(dimension, source, 'max')
           },
           {
             name: 'average',
             data: get_chart_data(dimension, source, 'avg')
           },
           {
             name: 'min',
             data: get_chart_data(dimension, source, 'min')
           },
         ];
  }

  function get_meter_series_set(dimension, source) {
    return [
           {
             name: 'sum',
             data: get_chart_data(dimension, source, 'sum')
           },
         ];
  }

  function get_chart_data(dimension, source, series) {
    result = [];
    $.each(my_history['_' + dimension][source], function(index, value) {
      result.push([value['tag']*1000, value['values'][series]]);
    })
    return result;
  };



}).call(this); 
