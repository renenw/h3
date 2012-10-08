module Alarm_Handlers

	def after_received_alarm_armed(payload)
		time = Time.at(payload['local_time'])
		message = {
			:guid 		=> payload['guid'],
			:twitter 	=> true,
			:message 	=> "#{( payload['integer_value']==0 ? 'Disarmed' : 'Armed' )}. Set at #{time.hour}:#{time.min}."
		}
		@fan_out_exchanges[:holler][:exchange].publish message.to_json
	  payload
	end

end