require 'logger'
require 'benchmark'
require 'time'
require 'json'

require './config'

class Log_Wrapper
	
	def initialize
		@log = Logger.new(LOG_FILE, 10, 1024000)
	end

	# expects a message (arg[0]) and a hash (arg[1])
	# if the hash includes a payload (and no explicit guid), the payload will be probed for a guid
	def method_missing(method, *args, &block)

		exception = nil

		message, called_by, guid, hash = get_parameters(args)
		if block_given?
			result, exception = execute_block(&block)
			hash.merge!(result)
		end

		@log.__send__(method, called_by) do
			"#{guid} | #{message} | #{(hash ? hash.to_json : '')}"
		end

		p message unless method == :debug

		raise exception if exception

  end

  def self.grep(search)
  	open('log.txt') do |f| f.grep(/#{search}/) do |e|
  			severity, date, pid, label, app, message, guid, actual_message, json = nil
  			e.gsub(/([\w]+),\s+\[([^\]\s]+)\s+#([^\]]+)]\s+(\w+)\s+--\s+(\w+)?:\s+(.+)/) do |match|
  				severity, date, pid, label, app, message = $1, Time.parse($2), $3, $4, $5, $6
					e.gsub(/([\w-]*)\s\|\s(.*)\s\|\s(.*)/) do |parts|
						guid, actual_message, payload = $1, $2, $3
						json = JSON.parse(payload) if payload =~ /{.+}/
					end
				end
				{
					'severity' 					=> severity,
					'date'							=> date,
					'pid'								=> pid,
					'label'							=> label,
					'app'								=> app,
					'message'						=> actual_message,
					'guid'							=> guid,
					'times'							=> json['times'],
					'payload'						=> json['payload']
				}
  		end
  	end
  end


  private

  	def execute_block(&block)

  		error_detail, exception = nil

			timings = Benchmark.measure do
				begin
					block.call
				rescue => e
					exception = e
					error_detail = { 'exception' => {
																						'type'			=> e.class.to_s,
																						'message'		=> e.message,
																						'backtrace'	=> e.backtrace.join("<br/>")
																					}
													}
				end
			end

  		t = timings.to_a
  		result = { 'times' => {
				  		  			'user' 							=> t[1],
				  		  			'system' 						=> t[2],
				  		  			'elapsed' 					=> t[5]
				  		  		}
  		 					}
  		 result.merge!(error_detail) if error_detail

  		 return result, exception
  	end
  
	  def get_parameters(args)

			message = args[0]
			called_by = caller[1][/`([^']*)'/, 1]

			hash, guid = nil
			hash = args[1] if args[1] && args[1].is_a?(Hash)

			if hash
				guid = hash[:guid]
				unless guid
					guid = hash[:payload]['guid'] if hash[:payload]
				end
			end

			hash ||= {}

			return message, called_by, guid, hash
	  end

end