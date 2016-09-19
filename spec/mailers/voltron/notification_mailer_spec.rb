require "rails_helper"

describe Voltron::NotificationMailer, type: :mailer do

	let(:mailer) { Voltron::NotificationMailer }

	it "should pass the first hash of arguments as mail arguments" do

		mailer.notify({ to: "test@example.com", subject: "Test" }).deliver_now

		last_email = ActionMailer::Base.deliveries.last

		expect(last_email.header["to"].value).to eq("test@example.com")

		expect(last_email.header["subject"].value).to eq("Test")
	end

	it "should convert the second hash of arguments to instance variables" do

		mailer.notify({ to: "test@example.com", subject: "Test" }, { body: "Test Body" }).deliver_now

		last_email = ActionMailer::Base.deliveries.last

		expect(last_email.body.raw_source).to eq("<html>\n\t<body>\n\t\tTest Body\n\t</body>\n</html>\n")
	end

end
