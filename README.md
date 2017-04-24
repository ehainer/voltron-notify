[![Code Climate](https://codeclimate.com/github/ehainer/voltron-notify.png)](https://codeclimate.com/github/ehainer/voltron-notify)
[![Build Status](https://travis-ci.org/ehainer/voltron-notify.svg?branch=master)](https://travis-ci.org/ehainer/voltron-notify)

# Voltron::Notify

Voltron Notify is an attempt to join Twilio's SMS api with Rails' default mailer functionality into one single method.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'voltron-notify'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install voltron-notify

Then run the following to create the voltron.rb initializer (if not exists already) and add the notify config:

    $ rails g voltron:notify:install

## Usage

Once installed and configured, add `notifyable` at the top of any model you wish to be able to send notifications, such as:

```ruby
class User < ActiveRecord::Base

  notifyable [args]

end
```

`notifyable` will create a notifications association on whatever model it is called on. The one optional argument should be a hash with default SMS/Email ActiveJob options. See "ActiveJob Integration" below for more info on how/when the default options will be used.

Defined default options should look like so:

```ruby
class User < ActiveRecord::Base

  notifyable { sms: { wait: 10.minutes, queue: 'sms' }, email: { wait_until: 10.minutes.from_now, queue: 'mailers' } }

end
```

Once done, you can utilize Voltron Notify like so:

```ruby
@user = User.find(1)

@user.notifications.create do |n|
  # First argument is SMS message text, second argument is hash containing zero or more of: [:to, :from]
  n.sms "This is my message", to: "1 (234) 567-8910"

  # and/or ...

  # First argument is email subject, remaining arguments can consist of [:to, :from] or any other param you'd like,
  # they will all be converted to @variables for use in the mailer template
  n.email "This is the mail subject", { to: "info@example.com", param_one: "Hi there", param_two: "" }
end
```

While you may specify the :to and :from as one of the arguments, by default the :from value of each notification type comes from `Voltron.config.notify.email_from` and `Voltron.config.notify.sms_from`. The value of :to by default will attempt to be retrieved by calling `.phone` or `.email` on the notifyable model itself. So given a User model with attributes (or methods) `email` and `phone`, the following will send notifications to those values:

```ruby
@user = User.find(1) #<User id: 1, phone: "1234567890", email: "info@example.com", created_at: "2016-09-23 16:49:20", updated_at: "2016-09-23 16:49:20">

@user.notifications.create do |n|
  n.sms "Hello from SMS" # Will send to +1 (123) 456-7890
  n.email "Hello from Email" # Will send to info@example.com
end

# @user.notifications.build { |n| ... } ... followed by @user.save works the same way
```

Optionally, you may pass a block to the `sms` or `email` methods that allows for additional functionality, like including attachments or overriding the `email` method default mailer/method:

```ruby
@user.notifications.create do |n|
  n.sms "Hello from SMS" do
    attach "picture.jpg" # Attach an image using the rails asset pipeline by specifying just the filename
    attach "http://www.someimagesite.com/example/demo/image.png" # Or just provide a url to a supported file beginning with "http"
  end

  n.email "Hello from Email" do
    attach "picture.jpg" # Uses the asset pipeline like above
    attach "http://www.example.com/picture.jpg" # This WILL NOT work, email attachments don't work that way

    mailer SiteMailer # Default: Voltron::NotificationMailer
    method :send_my_special_notification # Default: :notify
    arguments @any, list, of.arguments, :you, would, @like # In this case, the arguments used by SiteMailer.send_my_special_notification()
  end
end
```

Note that both SMS and Email notifications have validations on the :to/:from fields, the email subject, and the SMS body text. Since `notifications` is an association, any errors in the actual notification content will bubble up, possibly preventing the `notifyable` model from saving. For that reason, it may be more logical to instead use a @notifyable.notifications.build / @notifyable.save syntax to properly handle errors that may occur.


## ActiveJob Integration

Voltron Notify supports sending both email (via deliver_later) and SMS (via Voltron::SmsJob and perform_later). To have all notifications be handled by ActiveJob in conjunction with Sidekiq/Resque/whatever you need only set the config value `Voltron.config.notify.use_queue` to `true`. If ActiveJob is configured properly notifications will send that way instead. You may also optionally set the delay for each notification by setting the value of `Voltron.config.notify.delay` to any time value (i.e. 5.minutes, 3.months, 0.seconds)

If the value of `Voltron.config.notify.use_queue` is `true`, additional methods for sending SMS/Email can be used to further control the ActiveJob params.

For +email+, the methods `deliver_now`, `deliver_now!`, `deliver_later`, `deliver_later!` are exposed, and accept the same arguments (if any) as those defined in [ActionMailer::MessageDelivery](http://edgeapi.rubyonrails.org/classes/ActionMailer/MessageDelivery.html). All methods are pass-thru's to their equivalent found within ActionMailer (i.e. - same as `MyMailer.invite.deliver_*`)

For +sms+, the methods `deliver_now` and `deliver_later` are exposed, and accept the same arguments as those defined in [ActiveJob::Core::ClassMethods](https://apidock.com/rails/ActiveJob/Core/ClassMethods/set). Each method serves as a sort of pass-thru for ActiveJob's `perform_now` and `perform_later`, and functions essentially the same way.

If not explicitly called, and `use_queue` is `true`, each notification method operates as if `deliver_later` was called with no arguments (or default arguments if specified, see documentation about `notifyable` above.) Note that any arguments passed to a method listed above will override the same options specified in the default options defined with `notifyable`

If `use_queue` is `false`, the +email+ method behaves as if `deliver_now` was called on it, and +sms+ is delivered in a non-backgrounded, blocking way... immediately.

Example usage:

```ruby
@user = User.find(1)

@user.notifications.build do |n|
  n.sms("Delayed Message").deliver_now(queue: 'sms') # Will call ActiveJob's +perform_now+
  n.email("Delayed Mail Subject", { param_one: "Hi there", param_two: "" }).deliver_later(wait: 5.minutes)
end

@user.save # Will finally perform the actual actions defined. Basically, +deliver_*+ does nothing until the notification is saved.
```


## Updating SMS Notifications

Also supported are Twilio status update callbacks for SMS notifications. To enable, you can add the following to your `routes.rb` file

```ruby
Rails.application.routes.draw do

  allow_notification_update(options={})

end
```

Without specifying, the default options for notification updates are as follows:

```
# The default url path that Twilio will POST updates to. Can be anything you want so long as it's a valid URL path
path: '/notification/update'

# The controller that will handle the notification update
controller: 'voltron/notification'

# The action that will perform the update
action: 'update'
```

If the value of `controller` or `action` are modified, it is assumed that whatever they point to will handle SMS notification updates. See the description column for "StatusCallback" parameter [here](https://www.twilio.com/docs/api/rest/sending-messages) for information on what Twilio will POST to the callback url. Or, take a look at this gems `app/controller/voltron/notification_controller.rb` file to see what it does by default.

In order for `allow_notification_update` to generate the correct callback url, please ensure the value of `Voltron.config.base_url` is a valid host name. By default it will attempt to obtain this information from the `:host` parameter of `Rails.application.config.action_controller.default_url_options` but if specified in the Voltron initializer that will 

Note that `allow_notification_update` does nothing if running on a host matching `/localhost|127\.0\.0\.1/i` Since Twilio can't reach locally running apps to POST to, the app will not even provide Twilio with the callback url to try it. If you have a local app host named Twilio will try and POST to it, but will obviously fail for the reasons previously stated. Basically, this feature only works on remotely accessible hosts.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ehainer/voltron-notify. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

