require "rails_helper"

describe Voltron::SmsJob, type: :job do

  before(:all) { ActiveJob::Base.queue_adapter = :test }

  before(:each) do
    # Skip after_create/before_create callbacks, we're testing the after_create logic here anyways
    Voltron::Notification::SmsNotification.skip_callback :create, :before
    Voltron::Notification::SmsNotification.skip_callback :create, :after
  end

  let(:sms) { Voltron::Notification::SmsNotification.create(to: "<ENTER_PHONE_NUMBER_HERE>", from: Voltron.config.notify.sms_from, message: "Test") }

  it "can enqueue an sms delivery job" do
    skip "Change :to phone number in spec/jobs/voltron/sms_job_spec.rb to a valid Twilio recipient number before running"
    Voltron::SmsJob.perform_later(sms)
    expect(Voltron::SmsJob).to have_been_enqueued.with(sms).on_queue("default")
  end

  it "can deliver an sms when performed" do
    skip "Change :to phone number in spec/jobs/voltron/sms_job_spec.rb to a valid Twilio recipient number before running"
    expect { Voltron::SmsJob.perform_now(sms) }.to change { sms.response.length }.by(1)
  end

end