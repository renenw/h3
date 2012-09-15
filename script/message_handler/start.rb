#!/usr/bin/env ruby
# encoding: utf-8

require "amqp"
require 'json'
require 'mysql2'
require 'tzinfo'
require './cacher'
require 'pp'
require './config'
require './initialisation_handlers2'

include Initialisation_Handlers

@mysql = Mysql2::Client.new(:host => "localhost", :username => "root", :database => "30_camp_ground_road")
@cache = Cacher.new('localhost:11211')

@queues = {
	:udp_message_received => { :next_queue => lambda do |result| udp_message_received_destination_queue(result) end },
	:initialise_structured_message2 => { :next_queue => lambda do |message| nil end },
	:other => { :exchange => :readings, :next_queue => 'yyy' }
}


def message_handler
  EventMachine.run do
    AMQP.connect(:host => RABBIT_HOST,  :password => RABBIT_PASSWORD) do |connection|

      channel  = AMQP::Channel.new(connection)

      @exchange = channel.direct(RABBIT_EXCHANGE)
      @readings_exchange = channel.fanout(RABBIT_PROCESS_EXCHANGE)

      @queues.each_key do |queue|
      	p "Binding to #{queue}"
      	channel.queue(queue.to_s, :auto_delete => false).subscribe do |message|
      		handle_message queue, message
      	end
      end

    end
  end
end

def handle_message(queue, message)
	p "Received a message for #{queue}: #{message}"
  result = send(queue, JSON.parse(message))
  if result && @queues[queue]
  	target = @queues[queue]
	  exchange = case target[:exchange]
						      	  when nil
						      	  	@exchange
						      	  when :readings
						      	  	@readings_exchange
						      	  end
	  routing_key = (target[:next_queue].is_a?(String) ? target[:next_queue] : target[:next_queue].call(result))
	  p "Routing Key: [#{routing_key}]"
	  p "Result: #{result}"
	  exchange.publish result.to_json, :routing_key => routing_key
	end
end

def initialise_monitors
  # add default names etc
  MONITORS.each do |key, value|
    value[:name] = key.gsub(/_/, ' ').split(' ').each{|word| word.capitalize!}.join(' ') unless value[:name]
  end
  @cache.set("monitors", MONITORS)
  pp @cache.get("monitors")
end

def run
  initialise_monitors
  message_processor = Thread.new() { message_handler }
  p "Started (main)"
  message_processor.join
end

run