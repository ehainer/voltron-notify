require "rails_helper"

describe Voltron::Notify, type: :module do

	let(:user) { FactoryGirl.build(:user) }

	before(:all) do
		Voltron.config.debug = false
		Voltron.config.base_url = "http://localhost:3000"
		Voltron.config.notify.sms_account_sid = "AC29e5a3de3d7ec13567c701d8807cd55b"
		Voltron.config.notify.sms_auth_token = "e3f2ea4cce981294ddb799313308e80d"
		Voltron.config.notify.sms_from = "+19707374178"
	end

	it "has a version number" do
		expect(Voltron::Notify::VERSION).not_to be nil
	end

	context "Email Notifications" do

		it "should send an email notification when associated model saved" do
			user.notifications.build { |n| n.email "Test" }

			expect { user.save }.to have_enqueued_job.on_queue("mailers")

			expect(user.notifications.count).to eq(1)

			expect(user.notifications.last.to_email).to eq user.email
		end

		it "should send an email with one or more attached files when saved" do
			user.notifications.build do |n|
				n.email "Test With Attachments" do
					attach "1.jpg"
					attach File.open(Voltron.asset.find("2.jpg"))
				end
			end

			expect { user.save }.to have_enqueued_job.on_queue("mailers")

			last_job_args = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:args]

			expect(last_job_args.last.keys).to eq(["1.jpg", "2.jpg", "_aj_symbol_keys"])

			#puts ActiveJob::Base.queue_adapter.enqueued_jobs.last[:args].last.keys
		end

		it "should fail to save if notification email subject is blank" do
			user.notifications.build { |n| n.email nil }
			user.save

			expect(user).to_not be_valid

			expect(user.errors.full_messages).to include "Notifications email subject cannot be blank"
		end

		it "should fail to save if notification email recipient is blank" do
			user.email = nil
			user.notifications.build { |n| n.email "Test" }
			user.save

			expect(user).to_not be_valid

			expect(user.errors.full_messages).to include "Notifications email recipient cannot be blank"
		end

		it "should have a non-empty request after delivering email" do
			user.notifications.build { |n| n.email "Test" }
			user.save

			expect(user.notifications.last.email_instance.request.length).to eq(1)
		end

	end

	context "SMS Notifications" do

		it "should send an sms notification when associated model saved" do
			#skip "Sends an SMS message"
			user.notifications.build { |n| n.sms "Test" }
			user.save

			response = JSON.parse(user.notifications.last.response)

			expect(response["sms"][0]["status"]).to eq("queued")

			expect(user.notifications.count).to eq(1)

			expect(user.notifications.last.to_phone).to eq user.phone

		end

		it "should send an sms with one or more attached images when saved" do
			#skip "Sends an SMS message"
			user.notifications.build do |n|
				n.sms "Test With Attachments" do
					attach "https://images.unsplash.com/photo-1436891678271-9c672565d8f6?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&s=19a603025f5f82e92731fadf96172acf"
					attach "1.jpg"
				end
			end
			user.save

			response = JSON.parse(user.notifications.last.response)

			expect(response["sms"][0]["status"]).to eq("queued")

			expect(user.notifications.count).to eq(1)

			expect(user.notifications.last.to_phone).to eq user.phone
		end

		it "should fail to save if notification sms message is blank" do
			user.notifications.build { |n| n.sms nil }
			user.save

			expect(user).to_not be_valid

			expect(user.errors.full_messages).to include "Notifications sms message cannot be blank"
		end

		it "should fail to save if notification sms recipient is invalid" do
			#skip "Sends an SMS message"
			user.notifications.build { |n| n.sms "Test", to: "abcdefg" }
			user.save

			expect(user).to_not be_valid

			expect(user.errors.full_messages).to include "Notifications sms recipient is not a valid phone number"
		end

		it "should fail to save if notification sms recipient is blank" do
			user.phone = nil
			user.notifications.build { |n| n.sms "Test" }
			user.save

			expect(user).to_not be_valid

			expect(user.errors.full_messages).to include "Notifications sms recipient cannot be blank"
		end

		it "should have a non-empty request after delivering sms" do
			#skip "Sends an SMS message"
			user.notifications.build { |n| n.sms "Test" }
			user.save

			expect(user.notifications.last.sms_instance.request.length).to eq(1)
		end

		it "should increase the size of the sms request array by number of messages - 1 when delivered" do
			#skip "Sends an SMS message"
			notification = user.notifications.build do |n|
				n.sms "Test With Attachment" do
					attach "https://images.unsplash.com/photo-1436891620584-47fd0e565afb?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&s=df6386c2e327ae9dbc7e5be0bef4e1d6"
					attach "2.jpg"
				end
			end

			expect { user.save }.to change(notification.sms_instance.request, :length).from(0).to(2)
		end

		it "should return false if phone number is not valid" do
			notification = user.notifications.build do |n|
				n.sms "Test", to: "abc123"
			end

			expect(notification.sms_instance.valid_phone?).to eq(false)
		end

	end

	#it "should have notifications if notifyable" do
	#	expect(user).not_to respond_to(:notifications)

	#	user.class.notifyable

	#	expect(user).to respond_to(:notifications)
	#	expect(user.notifications.count).to eq(0)
	#end

end
