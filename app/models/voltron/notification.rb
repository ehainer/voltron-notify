module Voltron
  class Notification < ActiveRecord::Base

    belongs_to :notifyable, polymorphic: true

    has_many :sms_notifications

    has_many :email_notifications

    before_validation :validate

    def email(subject, **args, &block)
      # Build the options hash from the provided arguments
      options = { subject: subject, from: Voltron.config.notify.email_from }.merge(**args)

      # Build a new SMS notification object
      notification_email = email_notifications.build(options)

      # If a block is provided, allow calls to methods like `attach`
      notification_email.instance_exec &block if block_given?
    end

    def sms(message, **args, &block)
      # Build the options hash from the provided arguments
      options = { message: message, from: Voltron.config.notify.sms_from }.merge(**args)

      # Build a new SMS notification object
      notification_sms = sms_notifications.build(options)

      # If a block is provided, allow calls to methods like `attach`
      notification_sms.instance_exec &block if block_given?
    end

    # Called from the before_validation callback within `notifyable`
    # makes one final pass to set the email and phone as the to attribute
    # If already set however, this does nothing. We do this because simply calling
    # `notifyable` here returns nil until it's actually saved
    def to(email, phone)
      email_notifications.each { |n| n.to ||= email }
      sms_notifications.each { |n| n.to ||= phone }
    end

    private

      def validate
        # Add SMS related errors to self
        sms_notifications.each do |n|
          n.errors.each do |error|
            self.errors.add :sms, error
          end
        end

        # Add Email related errors to self
        email_notifications.each do |n|
          n.errors.each do |error|
            self.errors.add :email, error
          end
        end
        #email_instance.errors.each { |error| self.errors.add :email, error }

        # Return false if there are any errors, stopping the save process
        return !self.errors.messages.any?
      end
  end
end
