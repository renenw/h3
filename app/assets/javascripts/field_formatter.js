(function() {
  
  window.FieldFormatter || (window.FieldFormatter = {});

  FieldFormatter.format_fields = function() {
    $('.time').each(function(index, e) {
      t = $(e);
      t.html( (new Date(Number(t.html()))).format("ddd mmm dd yyyy HH:MM:ss", true) );
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