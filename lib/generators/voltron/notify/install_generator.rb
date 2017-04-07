module Voltron
  module Notify
    module Generators
      class InstallGenerator < Rails::Generators::Base

        source_root File.expand_path('../../../templates', __FILE__)

        desc 'Add Voltron Notify initializer'

        def inject_initializer

          voltron_initialzer_path = Rails.root.join('config', 'initializers', 'voltron.rb')

          unless File.exist? voltron_initialzer_path
            unless system("cd #{Rails.root.to_s} && rails generate voltron:install")
              puts 'Voltron initializer does not exist. Please ensure you have the 'voltron' gem installed and run `rails g voltron:install` to create it'
              return false
            end
          end

          current_initiailzer = File.read voltron_initialzer_path

          unless current_initiailzer.match(Regexp.new(/# === Voltron Notify Configuration ===/))
            inject_into_file(voltron_initialzer_path, after: "Voltron.setup do |config|\n") do
<<-CONTENT

  # === Voltron Notify Configuration ===

  # Whether or not to use the ActiveJob queue to handle sending email/sms messages
  # A queue is still only used if configured via config.active_job.queue_adapter
  # config.notify.use_queue = false

  # How long to delay sending email/sms messages. Use this in conjunction with config.notify.use_queue
  # config.notify.delay = 0.seconds

  # Twilio account id number
  # config.notify.sms_account_sid = ''

  # Twilio authentication token
  # config.notify.sms_auth_token = ''

  # Default from phone number. Must be the number provided by Twilio.
  # Avoid the overhead of pre-formatting the number by entering in the format "+1234567890"
  # config.notify.sms_from = ''

  # Default from email address. If not specified the default from in the mailer or the :from param on mail() is used
  # config.notify.email_from = 'no-reply@example.com'

  # The below 3 options define how email is sent. Each can be overridden within the `notification.email` block
  # by using the corresponding methods: `mailer`, `method`, and `template`
  # config.notify.default_mailer = Voltron::NotificationMailer

  # Within the mailer you define when sending a notification, this is the method that will be called
  # So in the default case, `Voltron::NotificationMailer.notify(...)` will be called
  # config.notify.default_method = :notify

  # The default mail view template to use
  # Note that if you decide to use a custom mailer/method, this becomes irrelevant
  # as you'll have the ability to set the template as you see fit within the mailer's method itself
  # config.notify.default_template = 'voltron/notification_mailer/notify.html.erb'
CONTENT
            end
          end
        end

        def copy_migrations
          copy_migration 'create_voltron_notifications'
          copy_migration 'create_voltron_notification_sms_notifications'
          copy_migration 'create_voltron_notification_email_notifications'
          copy_migration 'create_voltron_notification_sms_notification_attachments'
        end

        def copy_views
          copy_file '../../../app/views/voltron/notification_mailer/notify.html.erb', Rails.root.join('app', 'views', 'voltron', 'notification_mailer', 'notify.html.erb')
        end

        protected

          def copy_migration(filename)
            if migration_exists?(Rails.root.join('db', 'migrate'), filename)
              say_status('skipped', "Migration #{filename}.rb already exists")
            else
              copy_file "db/migrate/#{filename}.rb", Rails.root.join('db', 'migrate', "#{migration_number}_#{filename}.rb")
            end
          end

          def migration_exists?(dirname, filename)
            Dir.glob("#{dirname}/[0-9]*_*.rb").grep(/\d+_#{filename}.rb$/).first
          end

          def migration_id_exists?(dirname, id)
            Dir.glob("#{dirname}/#{id}*").length > 0
          end

          def migration_number
            @migration_number ||= Time.now.strftime("%Y%m%d%H%M%S").to_i

            while migration_id_exists?(Rails.root.join('db', 'migrate'), @migration_number) do
              @migration_number += 1
            end

            @migration_number
          end
      end
    end
  end
end