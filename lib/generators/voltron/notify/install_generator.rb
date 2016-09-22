module Voltron
  module Notify
    module Generators
      class InstallGenerator < Rails::Generators::Base

        source_root File.expand_path("../../../templates", __FILE__)

        desc "Add Voltron Notify initializer"

        def inject_initializer

          voltron_initialzer_path = Rails.root.join("config", "initializers", "voltron.rb")

          unless File.exist? voltron_initialzer_path
            unless system("cd #{Rails.root.to_s} && rails generate voltron:install")
              puts "Voltron initializer does not exist. Please ensure you have the 'voltron' gem installed and run `rails g voltron:install` to create it"
              return false
            end
          end

          current_initiailzer = File.read voltron_initialzer_path

          unless current_initiailzer.match(Regexp.new(/^\s# === Voltron Notify Configuration ===\n/))
            inject_into_file(voltron_initialzer_path, after: "Voltron.setup do |config|\n") do
<<-CONTENT

  # === Voltron Notify Configuration ===

  # Whether or not to use the ActiveJob queue to handle sending email/sms messages
  # A queue is still only used if configured via config.active_job.queue_adapter
  # config.notify.use_queue = false

  # How long to delay sending email/sms messages. Use this in conjunction with config.notify.use_queue
  # config.notify.delay = 0.seconds

  # Twilio account id number
  # config.notify.sms_account_sid = ""

  # Twilio authentication token
  # config.notify.sms_auth_token = ""

  # Default from phone number. Must be the number provided by Twilio.
  # Avoid the overhead of pre-formatting the number by entering in the format "+1234567890"
  # config.notify.sms_from = ""

  # Default from email address. If not specified the default from in the mailer or the :from param on mail() is used
  # config.notify.email_from = "no-reply@example.com"
CONTENT
            end
          end
        end

        def copy_migrations
          copy_file "db/migrate/create_voltron_notifications.rb", Rails.root.join("db", "migrate", "#{migration_time}_create_voltron_notifications.rb")
          copy_file "db/migrate/create_voltron_notification_sms_notifications.rb", Rails.root.join("db", "migrate", "#{migration_time}_create_voltron_notification_sms_notifications.rb")
          copy_file "db/migrate/create_voltron_notification_email_notifications.rb", Rails.root.join("db", "migrate", "#{migration_time}_create_voltron_notification_email_notifications.rb")
          copy_file "db/migrate/create_voltron_notification_sms_notification_attachments.rb", Rails.root.join("db", "migrate", "#{migration_time}_create_voltron_notification_sms_notification_attachments.rb")
        end

        def migration_time
          @migration_id ||= Time.now.strftime("%Y%m%d%H%M%S").to_i
          @migration_id += 1
        end
      end
    end
  end
end