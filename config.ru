require './app'

configure do
	set :twilio_sid, '[your app sid]' 
	set :twilio_token, '[your twilio token]'
	set :twilio_caller_id, '[your twilio number]'
	set :twilio_mobile_number, '[your mobile number]'
end	 


run Sinatra::Application