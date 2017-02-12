module Voltron
  module Notify
    module Routes

      def allow_notification_update(options={})
        path = (options[:path] || "/notification/update").gsub(/(^[\s\/]+)|([\s\/]+$)/, '')
        controller = (options[:controller] || "voltron/notification")
        action = (options[:action] || "update")
        post path, to: "#{controller}##{action}", as: :update_voltron_notification
      end

    end
  end
end
