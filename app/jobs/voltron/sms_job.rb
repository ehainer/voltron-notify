class Voltron::SmsJob < ActiveJob::Base

  def perform(sms)
    sms.send(:send_now)
  end

end