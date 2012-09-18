#!/usr/bin/env ruby
# encoding: utf-8

require "amqp"
require 'json'
require 'mysql2'
require 'tzinfo'
require './cacher'
require 'pp'
require './config'
require './log_wrapper'

require './lifecycle_handlers'
require './mrtg_handlers'
require './monitor_handlers'
require './reading_handlers'

include Lifecycle_Handlers
include MRTG_Handlers
include Monitor_Handlers
include Reading_Handlers

@mysql = Mysql2::Client.new(:host => "localhost", :username => "root", :database => "30_camp_ground_road")
@cache = Cacher.new('localhost:11211')
@log   = Log_Wrapper.new

# on_receive (called for both the source type, and the source. Returning nil halts processing)
# after_received

@queues = {
	:udp_message_received 							=> { :next_queue => :on_receive },
	:on_receive       									=> { :next_queue => :initialise_structured_message },
	:initialise_structured_message  		=> { :next_queue => lambda do |result| (result['source_type']=='pulse' ? 'handle_pulse_specific_calculations' : 'add_converted_values') end },
	:add_converted_values								=> { :next_queue => :after_received },
	:handle_pulse_specific_calculations => { :next_queue => :after_received },
	:after_received											=> { :next_queue => :reading },
	:reading 														=> {
																						:exchange => :readings,
																						:queues		=> [ 'cache_reading', 'summarisation', 'handle_history', 'calculate_outlier_threshold', 'cache_sources' ]
																					}
}
# :on_receive       							=> { :next_queue => lambda do |result| udp_message_received_destination_queue(result) end },

def message_handler
  EventMachine.run do
    AMQP.connect(:host => RABBIT_HOST,  :password => RABBIT_PASSWORD) do |connection|

      channel  = AMQP::Channel.new(connection)

      @exchange = channel.direct(RABBIT_EXCHANGE)
      @readings_exchange = channel.fanout(RABBIT_PROCESS_EXCHANGE)

      @queues.each_key do |queue|
      	if @queues[queue][:queues]
      		@queues[queue][:queues].each do |fanout_queue|
	      		@log.info "Binding to fanout queue: #{fanout_queue}"
	      		# TODO Make the selection of the exchange more elegant / not hard coded
	      		channel.queue(fanout_queue, :auto_delete => false).bind(@readings_exchange).subscribe do |message|
		      		handle_message fanout_queue, message
		      	end
		      end
      	else
	      	@log.info "Subscribing to: #{queue}"
	      	channel.queue(queue.to_s, :auto_delete => false).subscribe do |message|
	      		handle_message queue, message
	      	end
	      end
      end

    end
  end
end

def handle_message(queue, message)
	@log.debug "Handle: #{queue}: #{message}"
  result = __send__(queue, JSON.parse(message))
  if result && @queues[queue]
  	target = @queues[queue]
  	case target[:exchange]
    	  when :readings
    	  	@readings_exchange.publish result.to_json
  	  	else
  	  		routing_key = (target[:next_queue].is_a?(Symbol) ? target[:next_queue] : target[:next_queue].call(result))
  	  		@exchange.publish result.to_json, :routing_key => routing_key.to_s
    	  end
	  
	end
end

def initialise_monitors
  # add default names etc
  MONITORS.each do |key, value|
    value[:name] = key.gsub(/_/, ' ').split(' ').each{|word| word.capitalize!}.join(' ') unless value[:name]
  end
  @cache.set("monitors", MONITORS)
  #pp @cache.get("monitors")
end

def run
  initialise_monitors
  message_processor = Thread.new() { message_handler }
  @log.info "Started (main)"
  message_processor.join
end

run



=begin

* the data structure passed through the message chain

Payload is gradually augmented.

udp adds the time the packet was received
udp_handler (handle_udp):
  1. kills badly structured messages
  2. records unkown (ie, not in config.rb) monitors in a dead-letter-list,
  3. for valid messages, a data_store (location) is added, a local time is added, and the message is sent on to initialise_structured_message
  4. if the message is a mrtg message, it is sent to handle_mrtg_pre_processing
the various handle_xxxx handlers add a "converted_value" entry that is the result of assessing the value received in the payload

the handle_xxx adds a "converted_value" entry that reflects the value to be used by subsequent operations.
  
* the queue flow

udp
  => udp_handler (handle_udp): an opportunity to rewrite messages, ditch them etc
    => by default, initialise_structured_message (initialise_structured_message): messages should, by this point, have a basic "events" structure (source, number) with a received time that as closely as practically reflects the event time
      => if :pulse, pulse (handle_pulse): converted_value set to watt_hours since last reading (by implication, only handles watt_hours)
        => reading
      => if :gauge, gauge (handle_gauge): converted_value set to "float value"
        => reading
      => if :counter, counter (handle_gauge)
        => reading
    => if :mrtg, handle_mrtg_pre_processing: which pushes out three new entries - bandwidth in, out and total - but does not pass itsel along for further processing (it commits suicide)
 
  reading (handle_reading): saves the entry into the "readings" table and pushes the reading out into the fan out exchange
    => handle_summarisation: updates the summary data with this reading (eg, quarterly total, max, min etc)
    => handle_history: keeps a recent set of entries around in the cache (eg 200)
    => handle_calculate_outlier_threshold: for pulse meters, updates the cache with outlier thresholds (if relevant)
    => handle_cache_reading: pushes the latest reading into memcache
    => handle_cache_sources: makes sure the list of known sources (used by the js) is up-to-date

=end