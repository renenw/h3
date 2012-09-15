#!/usr/bin/env ruby
# encoding: utf-8

require 'amqp'
require 'json'
require './config'

#RABBIT_HOST     = '127.0.0.1'
#RABBIT_PASSWORD = '2PvvWRzgrivs'

#RABBIT_EXCHANGE = ''

unless ARGV.length == 2
	p 'Please supply a queue (routing_key) and a message (in that order).'
	exit
end

EventMachine.run do
	amqp_client = AMQP.connect(:host => RABBIT_HOST,  :password => RABBIT_PASSWORD)
	channel  = AMQP::Channel.new(amqp_client)
	exchange = channel.direct(RABBIT_EXCHANGE)
	message = { 'received' => Time.now.to_f, 'packet' => ARGV[1].strip }.to_json
	exchange.publish message, :routing_key => ARGV[0]
end