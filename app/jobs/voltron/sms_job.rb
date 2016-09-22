class Voltron::SmsJob < ActiveJob::Base

  def perform(sms)
    sms.deliver_now
  end

end