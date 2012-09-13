module Monitor_Handlers

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

end