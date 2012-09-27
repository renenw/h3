require 'logger'
require 'benchmark'

class Log_Wrapper
	
	def initialize
		@log = Logger.new('log.txt', 10, 1024000)
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