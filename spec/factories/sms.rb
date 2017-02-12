FactoryGirl.define do
  factory :sms, class: Voltron::Notification::SmsNotification do
    sid "ABC123"
    status "queued"
  end
end
