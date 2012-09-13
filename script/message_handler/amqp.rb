#!/usr/bin/env ruby
# encoding: utf-8

require "amqp"
require 'json'
require 'mysql2'
require 'tzinfo'
require './cacher'
require 'pp'
require './config'
require './reading_handlers'

include Reading_Handlers

@mysql = Mysql2::Client.new(:host => "localhost", :username => "root", :database => "30_camp_ground_road")
@cache = Cacher.new('localhost:11211')

def main

  initialise_monitors
  mesage_processor = Thread.new() { de_queuer }

  p "Started"

  mesage_processor.join

end

=begin

* todo

bandwidth must be wrong. It's defined as a pulse meter, but the pulse handler converts everything to watt hours!

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

      channel.queue('handle_mrtg_pre_processing', :auto_delete => false).subscribe do |message|
        handle_mrtg_pre_processing(message)
      end

      channel.queue('counter', :auto_delete => false).subscribe do |message|
        handle_gauge(message)
      end

      channel.queue('gauge', :auto_delete => false).subscribe do |message|
        handle_gauge(message)
      end

      channel.queue('pulse', :auto_delete => false).subscribe do |message|
        handle_pulse(message)
      end

      channel.queue('reading', :auto_delete => false).subscribe do |message|
        handle_reading(message)
      end

      channel.queue('summariser', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_summarisation(message)
      end

      channel.queue('historifier', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_history(message)
      end

      channel.queue('calculate_outlier_threshold', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_calculate_outlier_threshold(message)
      end

      channel.queue('cache_reading', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_cache_reading(message)
      end

      channel.queue('cache_sources', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_cache_sources(message)
      end

    end
  end
end

# an opportunity to rewrite messages, ditch them etc
def handle_udp(message)
  payload = JSON.parse(message)
  p "New message: #{message}" if message =~ /alarm/
  data = payload['packet'].scan(/[\w\.]+/)
  if data && data[0] && MONITORS[data[0]]
    source_type = MONITORS[data[0]][:monitor_type]
    next_handler = 'initialise_structured_message'
    if source_type
      next_handler = 'handle_mrtg_pre_processing' if source_type == :mrtg
      @exchange.publish payload.merge(
                                      { 'data_store' => '30_camp_ground_road',
                                        'source' => data[0],
                                        'source_type' => source_type.to_s
                                       }
                                   ).to_json, :routing_key => next_handler
    end
  else
    recent_reading = {
                       'local_time' => get_local_time(SETTINGS['timezone'], Time.at(payload['received'].to_f)).to_f*1000,
                       'Unknown' => true,
                       'payload' => payload,
                     }
    @cache.array_append("30_camp_ground_road.anomoly_log", recent_reading, PAYLOAD_HISTORY_ITEMS)
    p "Unknown: #{recent_reading}"
  end
end

def handle_mrtg_pre_processing(message)
  payload = JSON.parse(message)
  #puts "MRTG message received: #{payload}"
# "packet"=>"bandwidth 1330463695 2198531 2374663"
  data = payload['packet'].scan(/[\w\.]+/)
  inbound = data[2]
  outbound = data[3]
  inbound_message = { 'received' => payload['received'], 'packet' => "#{payload['source']}_in #{inbound}" }.to_json
  outbound_message = { 'received' => payload['received'], 'packet' => "#{payload['source']}_out #{outbound}" }.to_json
  combined_message = { 'received' => payload['received'], 'packet' => "#{payload['source']}_total #{outbound.to_i + inbound.to_i}" }.to_json
  @exchange.publish inbound_message, :routing_key => 'udp_handler'  
  @exchange.publish outbound_message, :routing_key => 'udp_handler'
  @exchange.publish combined_message, :routing_key => 'udp_handler'
end

# messages should, by this point, have a basic "events" structure (source, number) with a received time that as closely as practically reflects the event time
def initialise_structured_message(message)
  #puts "Initialise structured message: #{message}."
  payload = JSON.parse(message)
  data = payload['packet'].scan(/[\w\.]+/)
  i = data[1].to_f.round.to_i
  event_time_in_utc = Time.at(payload['received'].to_f)
  local_time = get_local_time(SETTINGS['timezone'], event_time_in_utc)
  @mysql.query("insert into events (source, float_value, integer_value, created_at) values ('#{data[0]}', #{data[1]}, #{i}, '#{event_time_in_utc.strftime('%Y-%m-%d %H:%M:%S.%6N')}');")
  event_id = @mysql.last_id
  @exchange.publish payload.merge(
                                    {
                                      'local_time' => local_time.to_f,
                                      'dimensions' => get_tagged_dimensions(local_time),
                                      'event_id' => event_id,
                                      'float_value' => data[1].to_f,
                                      'integer_value' => i
                                    }
                                 ).to_json, :routing_key => payload['source_type']
end




def handle_counter
  payload = JSON.parse(message)
  @exchange.publish payload.merge( { 'converted_value' => payload['float_value'] } ).to_json, :routing_key => 'reading'
end

def handle_gauge(message)
  payload = JSON.parse(message)
  @exchange.publish payload.merge( { 'converted_value' => payload['float_value'] } ).to_json, :routing_key => 'reading'
end

def handle_pulse(message)
  payload = JSON.parse(message)
  prior_pulses = @cache.fetch("#{payload['data_store']}.pulse.last.#{payload['source']}") do
    p "pulse miss"
    pulses = nil
    @mysql.query("select max(integer_value) as pulses from #{payload['data_store']}.events where source = '#{payload['source']}' and id < #{payload['event_id']};").each do |row|
      pulses = row['pulses']
    end
    pulses
  end
  if prior_pulses
    elapsed_pulses = payload['integer_value'] - prior_pulses
    # this is kuk. should pass conversion function using monitors structure at start
    converted_value = elapsed_pulses
    converted_value = pulse_to_watt_hours(elapsed_pulses) unless payload['source'] =~ /band/
    @exchange.publish payload.merge( { 'converted_value' => converted_value } ).to_json, :routing_key => 'reading'
  end
  @cache.set("#{payload['data_store']}.pulse.last.#{payload['source']}", payload['integer_value'])
end

def pulse_to_watt_hours(pulses)
  pulses * 10
end

def get_local_time(timezone, event_time_in_utc)
  tz = TZInfo::Timezone.get(timezone)
  tz.utc_to_local(event_time_in_utc)
end

def get_tagged_dimensions(local_time)
  tagged_dimensions = { 'all_time' => 0 }
  dimensions = get_dimensions(local_time)
  dimensions.each do |key, value|
    tagged_dimensions[key] = get_dimension_tag(key, dimensions)
  end
  tagged_dimensions
end

def get_dimensions(local_time)
  {
    'year'       => local_time.year,
    'month'      => local_time.month,
    'day'        => local_time.day,
    'week'       => local_time.strftime('%U').to_i,
    'yday'        => local_time.yday,
    'hour'       => local_time.hour,
    '5minute'    => ( ( local_time.min * 2) / 10 ) * 5,
    '10minute'   => local_time.min / 10 * 10,
    '15minute'   => local_time.min / 15 * 15,
    '30minute'   => local_time.min / 30 * 30,
  }
end

def get_dimension_tag(dimension, t)

  r = nil
  r = Time.utc(t['year'])                                                            if dimension == 'year'
  r = Time.utc(t['year'], t['month'])                                                if dimension == 'month'
  r = Time.utc(t['year'], t['month'], t['day'])                                      if dimension == 'day'
  r = Time.utc(t['year'], t['month'], t['day'], t['hour'])                           if dimension == 'hour'

  r = Time.utc(t['year'], t['month'], t['day'], t['hour'], t['5minute'])             if dimension == '5minute'
  r = Time.utc(t['year'], t['month'], t['day'], t['hour'], t['10minute'])            if dimension == '10minute'
  r = Time.utc(t['year'], t['month'], t['day'], t['hour'], t['15minute'])            if dimension == '15minute'
  r = Time.utc(t['year'], t['month'], t['day'], t['hour'], t['30minute'])            if dimension == '30minute'

  r = Time.utc(t['year']) + (t['yday']-1) * 24 * 60 * 60                             if dimension == 'yday'

  if dimension == 'week'
    r = Time.utc(t['year'])
    while (r.strftime('%U').to_i < t['week'])
      r = r + 24 * 60 * 60
    end
  end

  r.to_i

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
