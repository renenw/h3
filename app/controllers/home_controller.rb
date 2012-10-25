class HomeController < ApplicationController

  def index
  	@readings 				= memcache.get_readings(params)
  	@inside_day     	= memcache.get_summary('data_store' => params['data_store'], 'source' => 'temperature_inside', 'dimension' => 'day' )['temperature_inside']['values']
  	@outside_day     	= memcache.get_summary('data_store' => params['data_store'], 'source' => 'temperature_outside', 'dimension' => 'day' )['temperature_outside']['values']
  end

end
