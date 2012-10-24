#!/usr/bin/env ruby
# encoding: utf-8

require 'amqp'
require 'json'
require 'securerandom'
require './config'
require 'em-websocket'
require 'log_wrapper'

@log     = Log_Wrapper.new
@sockets = []

# Creating a thread for the EM event loop
Thread.new do
  EventMachine.run do
  	p "starting websocket listener"
    # Creates a websocket listener
    EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8081) do |ws|
      ws.onopen do
        p 'creating socket'
        @sockets << ws
      end

      ws.onclose do
        puts 'closing socket'
        @sockets.delete ws
      end

      ws.onmessage do |message|
      	@log.debug "message ack", :guid=>message
      end

    end
  end
end

Thread.new do
  EventMachine.run do
  	p "starting amqp listener"
    AMQP.connect(:host => RABBIT_HOST,  :password => RABBIT_PASSWORD) do |connection|

      channel  = AMQP::Channel.new(connection)

      @log.info "Subscribing to websocket_broadcast queue"
    	channel.queue('websocket_broadcast', :auto_delete => false).subscribe do |message|
    		send_message_to_clients message
    	end
      
    end
  end
end

def send_message_to_clients(message)
  payload = JSON.parse(message)
	@log.debug "Sent to #{@sockets.length} clients", :payload => payload do
    payload.delete('data_store')
    sanitised_message = payload.to_json
  	@sockets.each do |s|
  		s.send sanitised_message
  	end
  end
end


sleep