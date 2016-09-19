class Voltron::SmsJob < ActiveJob::Base

	queue_as :sms

	def perform(sms)
		sms.deliver_now
	end

end