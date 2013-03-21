class AlarmController < ApplicationController

  # Ultimately, parses subject lines of emails sent by Paradox IP100 module.
  # I convert the emails to HTTP requests using the James mail server.

  skip_before_filter :verify_authenticity_token
  skip_before_filter :ensure_logged_in

  # POST /alarm
  def create
    description = CGI::escape(params[:subject])
    socket = UDPSocket.new
    socket.send("alarm_message #{description}", 0, 'localhost', 54545)
    render :nothing => true
  end

end
