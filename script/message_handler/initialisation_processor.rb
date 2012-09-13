#!/usr/bin/env ruby
# encoding: utf-8

require "amqp"
require 'json'
require 'mysql2'
require 'tzinfo'
require './cacher'
require 'pp'
require './config'
require './initialisation_handlers'

include Initialisation_Handlers

@mysql = Mysql2::Client.new(:host => "localhost", :username => "root", :database => "30_camp_ground_road")
@cache = Cacher.new('localhost:11211')

def main

  initialise_monitors
  mesage_processor = Thread.new() { de_queuer }

  p "Started Initialisation Processor"

  mesage_processor.join

end

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


def de_queuer
  EventMachine.run do
    AMQP.connect(:host => RABBIT_HOST,  :password => RABBIT_PASSWORD) do |connection|

      channel  = AMQP::Channel.new(connection)

      @exchange = channel.direct(RABBIT_EXCHANGE)
      @process_exchange = channel.fanout(RABBIT_PROCESS_EXCHANGE)

      channel.queue('udp_handler', :auto_delete => false).subscribe do |message|
        handle_udp(message)
      end

      channel.queue('initialise_structured_message', :auto_delete => false).subscribe do |message|
        initialise_structured_message(message)
      end

    end
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

main



#MONITORS = {
#  'electricity_total'   => { :monitor_type => :pulse, :expected_frequency => 60 },
#  'electricity_geyser'  => { :monitor_type => :pulse, :expected_frequency => 60 },
#  'temperature_cellar'  => { :monitor_type => :gauge, :expected_frequency => 300 },
#  'temperature_outside' => { :monitor_type => :gauge, :expected_frequency => 300 },
#  'temperature_inside'  => { :monitor_type => :gauge, :expected_frequency => 300 },
#  'temperature_pool'    => { :monitor_type => :gauge, :range => { :min => 0, :max => 40}, :expected_frequency => 300 },
#  'bandwidth'           => { :monitor_type => :mrtg, :expected_frequency => 60  },
#  'bandwidth_in'        => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60 },
#  'bandwidth_out'       => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60 },
#  'bandwidth_total'     => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60 },
#  'outlier'             => { :monitor_type => :counter },
#  'a0'                  => { :monitor_type => :counter, :name => 'Pool Monitor' }
#}
