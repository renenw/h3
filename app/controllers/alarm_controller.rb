class AlarmController < ApplicationController

  skip_before_filter :verify_authenticity_token

  ZONE_DEFINITIONS = {
    "02" => 'Cellar',
    "06" => 'Front door',
    "07" => 'Braai',
    "08" => 'Garden near kids rooms',
    "09" => 'Outside scullery door',
    "14" => 'Dining room',
    "15" => 'Family room',
    "16" => 'Stoep',
    "17" => 'House side of driveway',
    "18" => 'South side of driveway',
    "19" => 'Outhouse',
    "21" => 'Pedestrian entrance',
  }

  def index
    @events = Event.recent
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @summaries }
    end
  end


  # POST /alarm
  def create

    description = url_encode(params[:subject])

    socket = UDPSocket.new
    socket.send(message******************, 0, 'localhost', 54545)

    @event = Event.new( :source => 'alarm', :level => 'warn', :description => params[:subject] )

    # if the event is of low importance, push the level down
    if @event.description =~ /(Dis)?[aA]rming[\s]+Area [\d]+/
      @event.level = 'info'
    end
    if @event.description =~ /Alarm system reporting via phone failed/
      @event.level = 'info'
    end


    # if a circuit has triggered, bump the event level up a notch
    if @event.description =~ /Alarm\s+Area\s+\d+\s+Zone/
      @event.level = 'error'
      circuit = @event.description[/\d+\s*$/].strip
      @event.description = ZONE_DEFINITIONS[circuit] if ZONE_DEFINITIONS[circuit]
      @event.integer_value = circuit.to_i
    end

    respond_to do |format|
      if @event.save
        format.html { head :ok }
        format.xml  { render :xml => @event, :status => :created, :location => @event }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

end
