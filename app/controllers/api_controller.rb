class ApiController < ApplicationController

  skip_before_filter :verify_authenticity_token
  skip_before_filter :ensure_logged_in


  def get_readings
    respond_to do |format|
      format.json  { render :json => memcache.get_readings(params) }
    end
  end

  def get_history
    respond_to do |format|
      format.json  { render :json => memcache.get_history(params) }
    end
  end

  def get_sensor_list
    respond_to do |format|
      format.json  { render :json => memcache.get_sensor_list(params) }
    end
  end

  def get_summaries
    respond_to do |format|
      format.json  { render :json => memcache.get_summaries(params) }
    end    
  end

  def get_summary
    respond_to do |format|
      format.json  { render :json => memcache.get_summary(params) }
    end
  end

  def get_messages
    respond_to do |format|
      format.json  { render :json => memcache.get_messages(params) }
    end
  end

  def udp_put
    if params['data_store'] == '30_camp_ground_road'
      socket = UDPSocket.new
      socket.send("#{params['source']} #{params['value']}", 0, 'localhost', 54545)
      render :nothing => true, :status => 200
    else
      render :nothing => true, :status => 406
    end
  end

end


