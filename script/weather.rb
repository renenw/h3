#!/usr/bin/env ruby
# encoding: utf-8

require 'net/http' 
require 'json'
require 'date'
require 'socket'

http_response = Net::HTTP.get_response(URI.parse('http://www.weathersa.co.za/web/home.asp?sp=1&f=1112&z=Ctry&v=7&g=gT&h=0&m=Strm&anim=aStr&av=AvWarn&uid=&p=&dbug=&TL=1098.1112&PC=&mw=w&ht=&ib=1&f=1112&setTown=1'))  

forecast 	= []
today 		= Date.today
i 				= 0

http_response.body.gsub(/<b>(...)<\/b>.+?-(\w+)\.png.+?(\d+?)%,\s(\d+?)mm.+?(\d+?)&deg;.+?(\d+?)&deg;C.+?([NSWE]+?)<.+?(\d+?)\D+?.+?([NSWE]+?)<.+?(\d+?)km/mi) do |match|
	day, description, probability, rain, min_temp, max_temp, am_direction, am_speed, pm_direction, pm_speed = $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
	t = today + i
	forecast << {
								:day 					=> day,
								:date 				=> t,
								:description 	=> description, 
								:probability	=> probability, 
								:rain					=> rain, 
								:min 					=> min_temp, 
								:max 					=> max_temp,
								:am_direction => am_direction, 
								:am_speed			=> am_speed, 
								:pm_direction => pm_direction, 
								:pm_speed			=> pm_speed
							}
	i = i + 1
end

socket = UDPSocket.new
socket.connect('10.245.77.15', 54545)
socket.send("weather_forecast #{forecast.to_json}", 0)
