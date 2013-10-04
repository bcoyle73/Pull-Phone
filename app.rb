require 'sinatra'
require 'twilio-ruby'

# A hack around multiple routes in Sinatra
def get_or_post(path, opts={}, &block)
  get(path, opts, &block)
  post(path, opts, &block)
end

# Voice Request URL
get_or_post '/call/?' do
  @caller_number = params[:From]
  @caller_name = params[:CallerName] ||= "Unknown"
  @caller_city = params[:FromCity] ||= "Unkown"
  @caller_state = params[:FromState] ||= "Unknown"
  
  response = Twilio::TwiML::Response.new do |r|
    r.Sms "You have a call from #{@caller_name} in #{@caller_city}, #{@caller_state} Would you like to take the call?",
              :from => settings.twilio_caller_id,
              :to => settings.twilio_mobile_number
    r.Enqueue "pull_q", :waitUrl => '/queue'
  end  
  response.text
end

# While in queue URL
get_or_post '/queue/?' do
  response = Twilio::TwiML::Response.new do |r|
    r.Say 'Thank you for calling.  Please hold for the next available person', :voice => 'Alice'
    r.Play 'http://com.twilio.sounds.music.s3.amazonaws.com/MARKOVICHAMP-Borghestral.mp3'
  end
  response.text
end

# SMS Request URL
get_or_post '/sms/?' do
  # check the source of the SMS
  logger.info params[:From]
  logger.info settings.twilio_mobile_number
  if params[:From] == settings.twilio_mobile_number
    client = Twilio::REST::Client.new settings.twilio_sid, settings.twilio_token
    #pull the call from the front of the queue
    queues = client.account.queues.list()
    queues.each do |queue|
      logger.info queue.friendly_name
      if queue.friendly_name == "pull_q"
        @call = client.account.queues.get(queue.sid).members.get("Front")
      end
    end
    
    case params[:Body].downcase
    when "no"
      url = base_url + "/message"
    # when "other key words and treatments"
    else
      url = base_url + "/connect"
    end

    @call.update(:url => url)
  end
  #need to respond to sms with blank response block
  response = Twilio::TwiML::Response.new do |r| end
  response.text       
end

get_or_post '/message/?' do
  response = Twilio::TwiML::Response.new do |r|
    r.Say 'Sorry but we are unable to take your call right now.  Please leave a message after the beep', 
          :voice => 'alice'
    r.Record :timeout => "10", :transcribe => "false"
    r.Hangup
  end
  response.text  
end

get_or_post '/connect/?' do
  response = Twilio::TwiML::Response.new do |r|
    r.Dial :callerId => settings.twilio_caller_id do |d|
      d.Number settings.twilio_mobile_number
    end
  end
  response.text  
end

helpers do
  def base_url
    @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
  end
end