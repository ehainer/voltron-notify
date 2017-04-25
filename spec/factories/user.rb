FactoryGirl.define do
  factory :user, class: User do
    email 'test@example.com'

    # Set this to a valid Twilio recipient number in order to allow SMS tests to run properly
    # If `blank?` all SMS sending tests will be skipped since they would fail otherwise
    phone nil
  end
end
