(function() {
  
 window.Templater || (window.Templater = {});

  Templater.populate_template = function(singular_element_name, data_hash, templater) {
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
 
}).call(this);