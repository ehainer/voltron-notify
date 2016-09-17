require "twilio-ruby"

module Voltron
	class Notification < ActiveRecord::Base

		belongs_to :notifyable, polymorphic: true

		before_validation :validate

		before_create :deliver

		def email(subject, **args, &block)
			# Flags Email as deliverable?
			email_instance.permit!
			# Set the recipient. If value of args[:to] is nil value of the notification's :to will be used,
			# or finally, `notifyable.email` will be tried automatically
			email_instance.to = args[:to]
			# Set the sender. If value of args[:from] is nil and the notifications :from is nil,
			# ultimately the default from in the mailer will be used
			email_instance.from = args[:from]
			# Set the email subject
			email_instance.subject = subject
			# All args are passed in as email args, which will be converted to instance variables within NotificationMailer
			email_instance.vars = args
			# If a block is provided, allow calls to methods like `attach`, `method`, `mailer` and `arguments`
			email_instance.instance_exec &block if block_given?
		end

		def sms(message, **args, &block)
			# Flags SMS as deliverable?
			sms_instance.permit!
			# Set the recipient. If value of args[:to] is nil value of `notifyable.phone` will be tried automatically
			sms_instance.to = args[:to]
			# Set the sender. If value of args[:from] is nil the default twilio from phone number will be used
			sms_instance.from = args[:from] || Voltron.config.notify.sms_from
			# Set the SMS message
			sms_instance.message = message
			# If a block is provided, allow calls to methods like `attach`
			sms_instance.instance_exec &block if block_given?
		end

		def email_instance
			@email ||= Email.new(notification: self)
		end

		def sms_instance
			@sms ||= SMS.new(notification: self)
		end

		def request_data
			@request_data ||= Hash.new
		end

		def response_data
			@response_data ||= Hash.new
		end

		# Called from the before_validation callback within `notifyable`
		# makes one final pass to set the email and phone as the to attribute
		# If already set however, this does nothing. We do this because simply calling
		# `notifyable` here returns nil until it's actually saved
		def to(email, phone)
			email_instance.to ||= email
			sms_instance.to ||= phone
		end

		class SMS

			attr_accessor :to, :from, :message, :attachments, :response, :notification

			def initialize(**args)
				args.each { |k, v| send "#{k}=", v }
				@attachments ||= []
				@permitted = false
				@result = {}
			end

			def request
				@result[:request] ||= []
			end

			def response
				@result[:response] ||= []
			end

			def deliver
				notification.to_phone = @to

				if attachments.length > 1
					begin
						client.messages.create({ from: from_formatted, to: to_formatted, media_url: attachments.shift }.compact)
						request << Rack::Utils.parse_nested_query(client.last_request.body)
						response << JSON.parse(client.last_response.body)
					end until attachments.length == 1
				end

				client.messages.create({ from: from_formatted, to: to_formatted, body: message, media_url: attachments.shift }.compact)
				request << Rack::Utils.parse_nested_query(client.last_request.body)
				response << JSON.parse(client.last_response.body)
			end

			def attach(url)
				if url.starts_with? "http"
					attachments << url
				else
					attachments << Voltron.config.base_url + ActionController::Base.helpers.asset_url(url)
				end
			end

			def deliverable?
				@permitted
			end

			def permit!
				@permitted = true
			end

			def valid_phone?
				begin
					return true if to.blank? # Handle a blank `to` separately in the errors method below
					to_formatted
					true
				rescue => e
					Voltron.log e.message, "Notify", :light_red
					false
				end
			end

			def errors
				output = []
				return output unless @permitted
				output << "recipient cannot be blank" if to.blank?
				output << "recipient is not a valid phone number" unless valid_phone?
				output << "sender cannot be blank" if from.blank?
				output << "message cannot be blank" if message.blank?
				output
			end

			private

				def to_formatted
					format to
				end

				def from_formatted
					format from
				end

				def format(input)
					# Try to format the number via Twilio's api
					# raises an exception if the input was invalid
					number = lookup.phone_numbers.get input
					number.phone_number
				end

				def client
					@client ||= ::Twilio::REST::Client.new Voltron.config.notify.sms_account_sid, Voltron.config.notify.sms_auth_token
				end

				def lookup
					@lookup ||= ::Twilio::REST::LookupsClient.new Voltron.config.notify.sms_account_sid, Voltron.config.notify.sms_auth_token
				end
		end

		class Email

			attr_accessor :to, :from, :subject, :vars, :attachments, :notification

			def initialize(**args)
				args.each { |k, v| send "#{k}=", v }
				@vars ||= {}
				@attachments ||= {}
				@mailer_class = "Voltron::NotificationMailer"
				@mailer_method = "notify"
				@mailer_arguments = nil
				@permitted = false
				@result = {}
			end

			def request
				@result[:request] ||= []
			end

			def response
				@result[:response] ||= []
			end

			def deliver
				notification.to_email = @to

				if @mailer_arguments.blank?
					request << { to: to, from: from, subject: subject }.compact.merge(vars: vars).merge(attachments: attachments)
					mail = mailer.to_s.classify.constantize.send method, { to: to, from: from, subject: subject }.compact, vars, attachments
				else
					request << @mailer_arguments.compact
					mail = mailer.to_s.classify.constantize.send method, *@mailer_arguments.compact
				end
				response << mail.deliver_later(wait: Voltron.config.notify.email_delay)
			end

			def attach(file, name = nil)
				name = File.basename(file) if name.blank?
				path = file

				if file.is_a?(File)
					path = file.path
					file.close
				elsif !File.exists?(path)
					path = Voltron.asset.find(path)
				end

				attachments[name] = path
			end

			def mailer(klass = nil)
				@mailer_class = klass || @mailer_class
			end

			def method(meth = nil)
				@mailer_method = meth || @mailer_method
			end

			def arguments(*args)
				@mailer_arguments = *args
			end

			def deliverable?
				@permitted
			end

			def permit!
				@permitted = true
			end

			def errors
				output = []
				return output unless @permitted
				output << "recipient cannot be blank" if to.blank?
				output << "subject cannot be blank" if subject.blank?
				output
			end
		end

		private

			def deliver
				if sms_instance.deliverable?
					sms_instance.deliver
					request_data[:sms] = sms_instance.request
					response_data[:sms] = sms_instance.response
					self.request = request_data.to_json
					self.response = response_data.to_json
				end

				if email_instance.deliverable?
					email_instance.deliver
					request_data[:email] = email_instance.request
					response_data[:email] = email_instance.response
					self.request = request_data.to_json
					self.response = response_data.to_json
				end
			end

			def validate
				# Add SMS related errors to self
				sms_instance.errors.each { |error| self.errors.add :sms, error }

				# Add Email related errors to self
				email_instance.errors.each { |error| self.errors.add :email, error }

				# Return false if there are any errors, stopping the save process
				return !self.errors.messages.any?
			end
	end
end
