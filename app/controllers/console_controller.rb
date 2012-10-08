class ConsoleController < ApplicationController

  def index
  end

  def graphs
  end

  def documentation
  end

  def readings
    target = 'reading_log'
    @heading = 'Recent Readings'
    if params['type'] == 'anomalies'
      target = 'anomoly_log'
      @heading = 'Anomalies'
    end
    @readings = memcache.get_array(target, params)
  end

  def log
    @log_detail = web_grep('/home/ubuntu/udp/log.txt', params['guid'])
  end

  private

    def web_grep(log_file, guid)
      log_lines, start_time, end_time, duration  = nil
      if guid && guid.length>0

        log                     = Log_Wrapper.new(log_file)
        log_lines               = log.grep(guid)
        user, system, elapsed   = 0.0, 0.0, 0.0
        slowest_duration        = -1.0
        timings                 = false

        if log_lines.length > 0
          start_time = end_time = log_lines[0]['date']
          log_lines.each do |e|
            date        = e['date']
            start_time  = date if date < start_time
            end_time    = date if date > end_time
            if e['times']
              user    += e['times']['user']
              system  += e['times']['system']
              elapsed += e['times']['elapsed']
              timings  = true
              slowest_duration = e['times']['elapsed'] if e['times']['elapsed'] > slowest_duration
            end
          end
        end

      end

      t = {}
      if timings
        t['times'] = { 'user' => user, 'system' => system, 'elapsed' => elapsed }
      end

      duration = (end_time - start_time) if end_time

      t.merge(
                {
                  'guid'             => guid,
                  'log_lines'        => log_lines,
                  'start_time'       => start_time,
                  'end_time'         => end_time,
                  'duration'         => duration,
                  'slowest_duration' => slowest_duration
                }
              )

    end

end