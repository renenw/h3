(function() {
  
  window.Data || (window.Data = {});
  
  Data.get_gauge_series_set = function(dimension, source) {
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
  
  Data.get_meter_series_set = function(dimension, source) {
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