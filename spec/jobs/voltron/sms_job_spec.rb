require 'rails_helper'

describe Voltron::SmsJob, type: :job do

  before(:all) { ActiveJob::Base.queue_adapter = :test }

  let(:user) { FactoryGirl.build(:user) }

  before(:each) do
    # Skip after_create/before_create callbacks, we're testing the after_create logic here anyways
    Voltron::Notification::SmsNotification.skip_callback :create, :before
    Voltron::Notification::SmsNotification.skip_callback :create, :after
  end

  let(:sms) { Voltron::Notification::SmsNotification.create(to: user.phone, from: Voltron.config.notify.sms_from, message: 'Test') }

  it 'can enqueue an sms delivery job' do
    skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
    Voltron::SmsJob.perform_later(sms)
    expect(Voltron::SmsJob).to have_been_enqueued.with(sms).on_queue('default')
  end

  it 'can deliver an sms when performed' do
    skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
    expect { Voltron::SmsJob.perform_now(sms) }.to change { sms.response.length }.by(1)
  end

end