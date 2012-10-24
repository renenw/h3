class HomeController < ApplicationController

  def index
  	@readings = memcache.get_readings(params);
  end

end
