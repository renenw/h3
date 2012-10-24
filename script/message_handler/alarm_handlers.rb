module Alarm_Handlers

	def after_received_alarm_armed(payload)
		
		broadcast_message_to_websockets 'alarm', ( payload['integer_value']==0 ? 'Disarmed' : 'Armed' ), payload

		time = Time.at(payload['local_time'])
		message = {
			:guid 		=> payload['guid'],
			:twitter 	=> true,
			:message 	=> "#{( payload['integer_value']==0 ? 'Disarmed' : 'Armed' )}. Set at #{time.strftime("%H:%M:%S")}."
		}
		@fan_out_exchanges[:twitter][:exchange].publish message.to_json
	  payload

	end

end