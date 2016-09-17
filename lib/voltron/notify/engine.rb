module Voltron
	module Notify
		class Engine < Rails::Engine

			isolate_namespace Voltron

			initializer "voltron.notify.initialize" do
				::ActiveRecord::Base.send :extend, ::Voltron::Notify
			end
		end
	end
end
