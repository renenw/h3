(function() {
  
  window.FieldFormatter || (window.FieldFormatter = {});

  FieldFormatter.format_fields = function() {
    $('.time').each(function(index, e) {
      t = $(e);
      f = t.data('time_format') || "ddd mmm dd yyyy HH:MM:ss";
      v = t.data('time') || t.html();
      if (!isNaN(v)) {
        t.html( (new Date(Number(v))).format(f, true) );
      }
    });
  
    $('.format').each(function(index, element) {
      e = $(element);
      value = e.html();
      v = "";
      if (value!="") {
        if (isNaN(value)) {
          v = value;
        } else {
          f = e.data('format');
          v = $.formatNumber(value, {format:f, locale:"gb"}).replace(/,/g,'&nbsp;');
        }
      }
      e.html(v);
    });
  }

}).call(this);