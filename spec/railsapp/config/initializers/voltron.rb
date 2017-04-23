Voltron.setup do |config|

  # === Voltron Notify Configuration ===

  # Whether or not to use the ActiveJob queue to handle sending email/sms messages
  # A queue is still only used if configured via config.active_job.queue_adapter
  config.notify.use_queue = true

  # Twilio account id number
  config.notify.sms_account_sid = 'AC76a148df070904500df20c6f5092e1fd'

  # Twilio authentication token
  config.notify.sms_auth_token = '8676524bd75ad3b84e2a708fbc16a7a8'

  # Default from phone number. Must be the number provided by Twilio.
  # Avoid the overhead of pre-formatting the number by entering in the format "+1234567890"
  config.notify.sms_from = '(970) 825-0220'

  # Default from email address. If not specified the default from in the mailer or the :from param on mail() is used
  config.notify.email_from = 'no-reply@example.com'

  # The below 3 options define how email is sent. Each can be overridden within the `notification.email` block
  # by using the corresponding methods: `mailer`, `method`, and `template`
  config.notify.default_mailer = Voltron::NotificationMailer

  # Within the mailer you define when sending a notification, this is the method that will be called
  # So in the default case, `Voltron::NotificationMailer.notify(...)` will be called
  config.notify.default_method = :notify

  # The default mail view template to use
  # Note that if you decide to use a custom mailer/method, this becomes irrelevant
  # as you'll have the ability to set the template as you see fit within the mailer's method itself
  config.notify.default_template = 'voltron/notification_mailer/notify.html.erb'

  # === Voltron Base Configuration ===

  # Whether to enable debug output in the browser console and terminal window
  config.debug = true

  # The base url of the site. Used by various voltron-* gems to correctly build urls
  config.base_url = 'http://localhost:3000'

  # What logger calls to Voltron.log should use
  config.logger = Logger.new(Rails.root.join('log', 'voltron.log'))

end