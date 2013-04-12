(function() {

  window.Home || (window.Home = {});

  Home.init = function() {
    $(".messages thead i").click(function() {
    	e = $(this);
    	// visual affordance on icon
    	e.toggleClass('icon-white');

    	// are we showing unimportant rows?
    	showUnimportant = $('.messages thead .icon-star').hasClass('icon-white');

    	// show or hide messages when importance visibility toggled
    	if (e.hasClass('icon-star')) {
    		if (showUnimportant) {
    			$('.messages tbody tr.displayed').show();
    		} else {
    			$('.messages tbody tr .icon-white').parent().parent().hide();
    		}
    	} else {
	    	// deal with message-types
	    	messageType = this.className.replace('icon-white','').trim();
	    	if (e.hasClass('icon-white')) {
	    		$('.messages tbody .' + messageType).parent().parent().hide().removeClass('displayed');
	    	} else {
	    		$('.messages tbody .' + messageType + (showUnimportant ? '' : '.not-white')).parent().parent().show();
	    		$('.messages tbody .' + messageType).parent().parent().addClass('displayed');
	    	}
	    	
	    }
    });
  }

}).call(this); 