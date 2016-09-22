module Voltron
  class Config

    def notify
      @notify ||= Notify.new
    end

    class Notify

      attr_accessor :use_queue, :delay

      # SMS config settings
      attr_accessor :sms_account_sid, :sms_auth_token, :sms_from

      # Email config settings
      attr_accessor :email_from

      def initialize
        @use_queue ||= false
        @delay ||= 0.seconds
        @email_from ||= "no-reply@example.com"
      end

    end
  end
end
