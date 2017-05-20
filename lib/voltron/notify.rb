require 'voltron'
require 'voltron/notify/version'
require 'voltron/notify/action_dispatch/routes'
require 'voltron/config/notify'

module Voltron
  module Notify

    LOG_COLOR = :light_yellow

    def notifyable(defaults={})
      @_notification_defaults = defaults.with_indifferent_access

      has_many :notifications, as: :notifyable, inverse_of: :notifyable, validate: true, autosave: true, class_name: '::Voltron::Notification'
    end
  end
end

require 'voltron/notify/engine' if defined?(Rails)
