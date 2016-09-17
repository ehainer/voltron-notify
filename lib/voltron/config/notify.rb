module Voltron
	class Config

		def notify
			@notify ||= Notify.new
		end

		class Notify

			# SMS config settings
			attr_accessor :sms_account_sid, :sms_auth_token, :sms_from

			# Email config settings
			attr_accessor :email_delay, :email_from

			def initialize
				@email_delay ||= 0.seconds
				@email_from ||= "no-reply@example.com"
			end

		end
	end
end
