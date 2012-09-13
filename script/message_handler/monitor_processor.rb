#!/usr/bin/env ruby
# encoding: utf-8

require "amqp"
require 'json'
require 'mysql2'
require 'tzinfo'
require './cacher'
require 'pp'
require './config'
require './monitor_handlers'

include Monitor_Handlers

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

=end


def de_queuer
  EventMachine.run do
    AMQP.connect(:host => RABBIT_HOST,  :password => RABBIT_PASSWORD) do |connection|

      channel  = AMQP::Channel.new(connection)

      @exchange = channel.direct(RABBIT_EXCHANGE)
      @process_exchange = channel.fanout(RABBIT_PROCESS_EXCHANGE)

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
