[![Coverage Status](https://coveralls.io/repos/github/ehainer/voltron-notify/badge.svg?branch=master)](https://coveralls.io/github/ehainer/voltron-notify?branch=master)
[![Build Status](https://travis-ci.org/ehainer/voltron-notify.svg?branch=master)](https://travis-ci.org/ehainer/voltron-notify)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](http://www.gnu.org/licenses/gpl-3.0)

# Voltron::Notify

Voltron Notify is an attempt to join Twilio's SMS api with Rails' default mailer functionality into one single method.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'voltron-notify', '~> 0.2.0'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install voltron-notify

Then run the following to create the voltron.rb initializer and add the notify config:

    $ rails g voltron:notify:install

## Usage

Once installed and configured, add `notifyable` at the top of any model you wish to be able to send notifications, such as:

```ruby
class User < ActiveRecord::Base

  notifyable [args]

end
```

`notifyable` will create a `notifications` association on whatever model it is called on. The one optional argument should be a hash with default SMS/Email ActiveJob options. See "ActiveJob Integration" below for more info on how/when the default options will be used.

Defined default options should look like so:

```ruby
class User < ActiveRecord::Base

  notifyable sms: { wait: 10.minutes, queue: 'sms' },
             email: { wait_until: 10.minutes.from_now, queue: 'mailers' }

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
  n.sms 'Hello from SMS' # Will send to +1 (123) 456-7890
  n.email 'Hello from Email' # Will send to info@example.com
end

# @user.notifications.build { |n| ... } ... followed by @user.save works the same way
```

Optionally, you may pass a block to the `sms` or `email` methods that allows for additional functionality, like including attachments or overriding the `email` method default mailer/method:

```ruby
@user.notifications.create do |n|
  n.sms 'Hello from SMS' do
    attach 'picture.jpg' # Attach an image using the rails asset pipeline by specifying just the filename
    attach 'http://www.someimagesite.com/example/demo/image.png' # Or just provide a url to a supported file beginning with 'http'
  end

  n.email 'Hello from Email' do
    attach 'picture.jpg' # Uses the asset pipeline like above
    attach 'http://www.example.com/picture.jpg' # This WILL NOT work, email attachments don't work that way

    mailer SiteMailer # Default: Voltron::NotificationMailer
    method :send_my_special_notification # Default: :notify
    arguments @any, list, of.arguments, :you, would, @like # In this case, the arguments used by SiteMailer.send_my_special_notification()
    template 'my_mailer/sub_dir/custom_template' # Default: 'voltron/notification_mailer/notify.html.erb'
  end
end
```

In the case of the methods `mailer`, `method`, `arguments`, and `template`, below is each's purpose and default values

| Method    | Default                                                                                                                                                                        | Comment                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
|-----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| mailer    | Voltron::NotificationMailer                                                                                                                                                    | Defines what mailer class should be used to handle the sending of email notifications. Can be defined as the actual class name or a string, even in the format '&lt;module&gt;/&lt;mailer&gt;'. It is eventually converted to a string anyways, converted to a valid format with [classify](https://apidock.com/rails/v4.2.7/String/classify) and then instantiated with [constantize](https://apidock.com/rails/String/constantize)                                                                                                                                                                                                                                                                               |
| method    | :notify                                                                                                                                                                        | Specifies what method within the defined mailer should be called. Can be a string or symbol                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| arguments | nil                                                                                                                                                                            | Accepts an unlimited number of arguments that will be passed directly through to your mailer method Can be anything you want, so long as +mailer+.+method+() will understand it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| template  | nil, but due to ActionMailer's default behavior, assuming `mailer` and `method` are not modified, it will look for `app/views/voltron/notification_mailer/notify.<format>.erb` | Overrides the default mailer template by parsing a single string argument into separate [template_path](http://guides.rubyonrails.org/action_mailer_basics.html#mailer-views) and [template_name](http://guides.rubyonrails.org/action_mailer_basics.html#mailer-views) arguments for the `mail` method. Note that this argument should be the path relative to your applications `app/views` directory, and that it strips any file extensions. So, in the case of a view located at `app/views/my_mailer/sub_dir/special_template.html.erb` you can specify the path `my_mailer/sub_dir/special_template`. Depending on what format email you've chosen to send it will look for `special_template.<format>.erb` |

Note that both SMS and Email notifications have validations on the :to/:from fields, the email subject, and the SMS body text. Since `notifications` is an association, any errors in the actual notification content will bubble up, possibly preventing the `notifyable` model from saving. For that reason, it may be more logical to instead use a @notifyable.notifications.build / @notifyable.save syntax to properly handle errors that may occur.

## ActiveJob Integration

Voltron Notify supports sending both email (via deliver_later) and SMS (via Voltron::SmsJob and perform_later). To have all notifications be handled by ActiveJob in conjunction with Sidekiq/Resque/whatever you need only set the config value `Voltron.config.notify.use_queue` to `true`. If ActiveJob is configured properly notifications will send that way instead. You may also optionally set the delay for each notification by setting the value of `Voltron.config.notify.delay` to any time value (i.e. 5.minutes, 3.months, 0.seconds)

If the value of `Voltron.config.notify.use_queue` is `true`, additional methods for sending SMS/Email can be used to further control the ActiveJob params.

For the `email` method:

| Queue Specific Methods Available | Accepts Arguments?                                                                                                                                                                                                                                                                                                                                                                                   | Behavior                                                                                                                                                                                | Default Behavior If Not Manually Called                                 |
|----------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| deliver_now                      | No                                                                                                                                                                                                                                                                                                                                                                                                   | Same as [deliver_now](https://apidock.com/rails/v4.2.7/ActionMailer/MessageDelivery/deliver_now), except this will not occur until the parent notification association is saved         | Yes, if `Voltron.config.notify.use_queue` is *not* truthy. No otherwise |
| deliver_now!                     | No                                                                                                                                                                                                                                                                                                                                                                                                   | Same as [deliver_now!](https://apidock.com/rails/ActionMailer/MessageDelivery/deliver_now%21), except this will not occur until the parent notification association is saved            | No                                                                      |
| deliver_later                    | Yes, same as what [deliver_later](https://apidock.com/rails/v4.2.7/ActionMailer/MessageDelivery/deliver_later) would accept. These arguments will come from the defaults specified when `notifyable` is called in the model. Default arguments are always overridden by the same options defined in this methods arguments. See documentation of `notifyable` and it's accepted arguments above.     | Same as [deliver_later](https://apidock.com/rails/v4.2.7/ActionMailer/MessageDelivery/deliver_later), except this will not occur until the parent notification association is saved     | Yes, if `Voltron.config.notify.use_queue` is truthy. No otherwise       |
| deliver_later!                   | Yes, same as what [deliver_later!](https://apidock.com/rails/v4.2.7/ActionMailer/MessageDelivery/deliver_later%21) would accept. These arguments will come from the defaults specified when `notifyable` is called in the model. Default arguments are always overridden by the same options defined in this methods arguments. See documentation of `notifyable` and it's accepted arguments above. | Same as [deliver_later!](https://apidock.com/rails/v4.2.7/ActionMailer/MessageDelivery/deliver_later%21), except this will not occur until the parent notification association is saved | No                                                                      |

For the `sms` method:

| Queue Specific Methods Available | Accepts Arguments?                                                                                                                                                                                                                                                                                                                                                   | Behavior                                                                                                                                                            | Default Behavior If Not Manually Called                                 |
|----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| deliver_now                      | No                                                                                                                                                                                                                                                                                                                                                                   | When associated notification object is saved, SMS will be sent immediately (via ActiveJob's [perform_now](https://apidock.com/rails/v4.2.1/ActiveJob/Execution/ClassMethods/perform_now)), in a blocking way, aka - rails will wait until SMS is sent before continuing execution. | Yes, if `Voltron.config.notify.use_queue` is *not* truthy. No otherwise |
| deliver_later                    | Yes, same as what [set](https://apidock.com/rails/ActiveJob/Core/ClassMethods/set) would accept. These arguments will come from the defaults specified when `notifyable` is called in the model. Default arguments are always overridden by the same options defined in this methods arguments. See documentation of `notifyable` and it's accepted arguments above. | When associated notification object is saved, ActiveJob's [perform_later](https://apidock.com/rails/ActiveJob/Enqueuing/ClassMethods/perform_later) is called.                                                                                                                     | Yes, if `Voltron.config.notify.use_queue` is truthy. No otherwise       |


Example usage:

```ruby
@user = User.find(1)

@user.notifications.build do |n|
  n.sms("Immediate Message").deliver_now # Will deliver the SMS as soon as the notification is saved
  n.sms("Delayed Message").deliver_later(queue: 'sms', wait_until: 10.minutes.from_now) # Will deliver the SMS via +perform_now+ with ActiveJob
  n.email("Delayed Mail Subject", { param_one: "Hi there", param_two: "" }).deliver_later(wait: 5.minutes) # Will pass through to ActionMailer's +deliver_later+ method
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

| Option     | Default              | Comment                                                                                                                   |
|------------|----------------------|---------------------------------------------------------------------------------------------------------------------------|
| path       | /notification/update | The default url path that Twilio will POST updates to. Can be anything you want so long as it's a valid URL path          |
| controller | voltron/notification | The controller that will handle the notification update (in this case `app/controllers/voltron/notification_controller.rb`) |
| action     | update               | The controller action (method) that will perform the update                                                               |

If the value of `controller` or `action` are modified, it is assumed that whatever they point to will handle SMS notification updates. See the description column for "StatusCallback" parameter [here](https://www.twilio.com/docs/api/rest/sending-messages) for information on what Twilio will POST to the callback url. Or, take a look at this gems `app/controller/voltron/notification_controller.rb` file to see what it does by default.

In order for `allow_notification_update` to generate the correct callback url, please ensure the value of `Voltron.config.base_url` is a valid host name. By default it will attempt to obtain this information from the `:host` parameter of `Rails.application.config.action_controller.default_url_options` but if specified in the Voltron initializer that will be used instead.

Note that `allow_notification_update` does nothing if running on a host matching `/localhost|127\.0\.0\.1/i` Since Twilio can't reach locally running apps to POST to, the app will not even provide Twilio with the callback url to try it. If you have a local app host named Twilio will try and POST to it, but will obviously fail for the reasons previously stated. Basically, this feature only works on remotely accessible hosts.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ehainer/voltron-notify. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [GNU General Public License](https://www.gnu.org/licenses/gpl-3.0.en.html).

