module Voltron
  module Notify
    class Engine < Rails::Engine

      isolate_namespace Voltron

      initializer "voltron.notify.initialize" do
        ::ActiveRecord::Base.send :extend, ::Voltron::Notify
        ::ActionDispatch::Routing::Mapper.send :include, ::Voltron::Notify::Routes
      end
    end
  end
end
