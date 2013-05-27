class SwitchController < ApplicationController

 def set_switch
  	socket = UDPSocket.new
    socket.send("switch_#{params['state']} #{params['source']}", 0, 'localhost', 54545)
  	render :nothing => true, :status => '200'
  end

end
