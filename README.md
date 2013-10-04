Pull-Phone
==========

A Twilio application to allow you to pull phone calls to your mobile phone.  The application will answer a call to your twilio number, send you a text message asking whether to take the call or not.  If you do want to take the call it will forward the call on to your mobile phone.  If you do not wish to take the call it will take a voicemail in Twilio.

Getting Started
---------------
+ You will need a Twilio account. If you don't have one signup [here](https://www.twilio.com/try-twilio)
+ Purchase a Phone Number and enable the CNAM lookup if you would like more info in your sms
+ Create a new TwimlApp with the Voice url pointing the /call endpoint and the Message url pointing the /sms endpoint
+ Update the config.ru file with your Twilio account info, number, and the mobile number Twilio will send SMS and forward calls to

Answering the Call
----------------------
When a call comes into your Twilio number we will send an SMS to your mobile number with the greeting in the code.  After sending the SMS it will place the call into queue and redirect to the /queue

```ruby
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
```

Queueing the Call
-------------------
After putting the call into queue the app redirects to the /queue end point which tells the app what to play the caller while in queue.  Here we tell the caller that we are finding someone to help and we play music.

```ruby
get_or_post '/queue/?' do
  response = Twilio::TwiML::Response.new do |r|
    r.Say 'Thank you for calling.  Please hold for the next available person', :voice => 'Alice'
    r.Play 'http://com.twilio.sounds.music.s3.amazonaws.com/MARKOVICHAMP-Borghestral.mp3'
  end
  response.text
end
```

Receiving the SMS with instructions
-----------------------------------
When we receive a SMS message we have to check the source of the SMS is authorized to manipulate a call then we have to find the call in the correct queue to manipulate it.  In this app we two SMS key words; yes to pull the call to mobile number or no to send caller to voicemail in Twilio.  Other keywords could be defined here along with adding new end points to redirect the call to.  The app is redirects either to /message or /connect.  At the end we need to return an empty Twiml response block as we do not want to reply to our own SMS

```ruby
get_or_post '/sms/?' do
  # check the source of the SMS
  if params[:From] == settings.twilio_mobile_number
    client = Twilio::REST::Client.new settings.twilio_sid, settings.twilio_token
    #pull the call from the front of the queue
    queues = client.account.queues.list()
    queues.each do |queue|
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
```

Taking a message
----------------
If we have decided not to take the call we can prompt the caller to leave a message, record the message, and hangup.  This is where you would customize the message.

```ruby
get_or_post '/message/?' do
  response = Twilio::TwiML::Response.new do |r|
    r.Say 'Sorry but we are unable to take your call right now.  Please leave a message after the beep', 
          :voice => 'alice'
    r.Record :timeout => "10", :transcribe => "false"
    r.Hangup
  end
  response.text  
end
```

Connecting the call
-------------------
If we have decided to take the call then we will connect the caller in queue with our mobile by dialing out to that number.

```ruby
get_or_post '/connect/?' do
  response = Twilio::TwiML::Response.new do |r|
    r.Dial :callerId => settings.twilio_caller_id do |d|
      d.Number settings.twilio_mobile_number
    end
  end
  response.text  
end
```





