FactoryGirl.define do
	factory :user, class: Voltron::User do
		email "test@example.com"
		phone "970-581-3387"
	end
end
