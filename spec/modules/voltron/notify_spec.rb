require "rails_helper"

describe Voltron::Notify, type: :module do

  include ActiveJob::TestHelper

  let(:user) { FactoryGirl.build(:user) }

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'has a version number' do
    expect(Voltron::Notify::VERSION).not_to be nil
  end

  context 'Email Notifications' do

    it 'should enqueue a notification when associated model saved' do
      Voltron.config.notify.use_queue = true
      user.notifications.build { |n| n.email 'Test' }

      expect { user.save }.to have_enqueued_job.on_queue('mailers')

      expect(user.notifications.count).to eq(1)
    end

    it 'should enqueue an email with one or more attached files when saved' do
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.email 'Test With Attachments' do
          attach '1.jpg'
          attach File.open(Voltron.asset.find('2.jpg'))
        end
      end

      expect { user.save }.to have_enqueued_job.on_queue('mailers')

      last_job_args = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:args]

      expect(last_job_args.last.keys).to eq(['1.jpg', '2.jpg', '_aj_symbol_keys'])
    end

    it 'should enqueue an email with attachments with a defined name' do
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.email 'Test With Attachments' do
          attach '1.jpg', 'mystery_file.jpg'
        end
      end

      expect { user.save }.to have_enqueued_job.on_queue('mailers')

      last_job_args = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:args]

      expect(last_job_args.last.keys).to eq(['mystery_file.jpg', '_aj_symbol_keys'])
    end

    it 'should be able to enqueue using a defined mailer, method, and arguments' do
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.email 'Test' do
          mailer ApplicationMailer
          method :test_mail
          arguments 'custom@example.com', 'Test Custom', 'Custom Body'
        end
      end

      expect { user.save }.to have_enqueued_job.on_queue('mailers')

      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.last[:args]).to eq(['ApplicationMailer', 'test_mail', 'deliver_now', 'custom@example.com', 'Test Custom', 'Custom Body'])
    end

    it 'should change the number of actionmailer deliveries by one if use_queue is false' do
      expect(Voltron.config.notify.use_queue).to eq(false)

      user.notifications.build { |n| n.email 'Test' }
      expect { user.save }.to change(ActionMailer::Base.deliveries, :count).by(1)
    end

    it 'should fail to save if notification email subject is blank' do
      user.notifications.build { |n| n.email nil }
      user.save

      expect(user).to_not be_valid

      expect(user.errors.full_messages).to include 'Subject cannot be blank'
    end

    it 'should fail to save if notification email recipient is blank' do
      user.email = nil
      user.notifications.build { |n| n.email 'Test' }

      expect(user).to_not be_valid

      expect(user.errors.full_messages).to include 'Recipient cannot be blank'
    end

    it 'should have a non-empty request email hash after delivering' do
      user.notifications.build { |n| n.email 'Test' }
      user.save

      expect(user.notifications.last.email_notifications.last.request).to_not be_blank
    end

    it 'should have a non-empty response email hash after delivering' do
      user.notifications.build { |n| n.email 'Test' }
      user.save

      expect(user.notifications.last.email_notifications.last.response).to_not be_blank
    end

    it 'should use a defined template if specified' do
      user.notifications.build do |n|
        n.email 'Test' do
          template 'custom_mailer/template.test.html.erb'
        end
      end

      user.save

      expect(user.notifications.last.email_notifications.last.template_path).to eq('custom_mailer')
      expect(user.notifications.last.email_notifications.last.template_name).to eq('template.test')
    end

    it 'should have a default mailer of Voltron::NotificationMailer' do
      expect(Voltron.config.notify.default_mailer).to eq(Voltron::NotificationMailer)
    end

    it 'should have a default mailer method of :notify' do
      expect(Voltron.config.notify.default_method.to_s).to eq('notify')
    end

    it 'should have a default mailer template of voltron/notification_mailer/notify.html.erb' do
      expect(Voltron.config.notify.default_template).to eq('voltron/notification_mailer/notify.html.erb')
    end

    it 'should be able to define a default mailer and method' do
      expect(Voltron.config.notify.default_mailer).to eq(Voltron::NotificationMailer)

      Voltron.config.notify.default_mailer = ApplicationMailer
      Voltron.config.notify.default_method = :test_mail

      user.notifications.build { |n| n.email 'Test' }
      user.save

      expect(user.notifications.last.email_notifications.last.mailer_class).to eq('ApplicationMailer')
      expect(user.notifications.last.email_notifications.last.mailer_method).to eq('test_mail')
    end

    it 'should inherit the default template as the mailer view' do
      expect(Voltron.config.notify.default_template).to eq('voltron/notification_mailer/notify.html.erb')

      Voltron.config.notify.default_template = 'custom_mailer/template.test.html.erb'

      user.notifications.build { |n| n.email 'Test' }
      user.save

      expect(user.notifications.last.email_notifications.last.template_path).to eq('custom_mailer')
      expect(user.notifications.last.email_notifications.last.template_name).to eq('template.test')
    end

    it 'should accept options for enqueueing a job via deliver_later' do
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.email('Test').deliver_later(wait: 10.minutes, queue: 'custom_mail_1')
      end

      expect { user.save }.to have_enqueued_job.on_queue('custom_mail_1')
    end

    it 'should accept options for enqueueing a job via deliver_later!' do
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.email('Test').deliver_later!(wait: 10.minutes, queue: 'custom_mail_2')
      end

      expect { user.save }.to have_enqueued_job.on_queue('custom_mail_2')
    end

    it 'should deliver the email now if deliver_now is explicitly called' do
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.email('Test').deliver_now
      end

      expect { user.save }.to change(ActionMailer::Base.deliveries, :count).by(1)
    end

    it 'should deliver the email now if deliver_now! is explicitly called' do
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.email('Test').deliver_now!
      end

      expect { user.save }.to change(ActionMailer::Base.deliveries, :count).by(1)
    end

  end

  context 'SMS Notifications' do

    it 'should send an sms notification when associated model saved' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      user.notifications.build { |n| n.sms 'Test' }
      user.save

      expect(user.notifications.last.sms_notifications.last.response.first[:status]).to eq('queued')

      expect(user.notifications.count).to eq(1)

      expect(user.notifications.last.sms_notifications.last.to).to eq user.phone
    end

    it 'should send an sms with one or more attached images when saved' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      user.notifications.build do |n|
        n.sms 'Test With Attachments' do
          attach 'https://images.unsplash.com/photo-1436891678271-9c672565d8f6?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&s=19a603025f5f82e92731fadf96172acf'
          attach '1.jpg'
        end
      end
      user.save

      expect(user.notifications.last.sms_notifications.last.response.first[:status]).to eq('queued')

      expect(user.notifications.count).to eq(1)

      expect(user.notifications.last.sms_notifications.last.to).to eq user.phone
    end

    it 'should fail to save if notification sms message is blank' do
      user.notifications.build { |n| n.sms nil }
      user.save

      expect(user).to_not be_valid

      expect(user.errors.full_messages).to include 'Message cannot be blank'
    end

    it 'should fail to save if notification sms recipient is invalid' do
      user.notifications.build { |n| n.sms 'Test', to: 'abcdefg' }
      user.save

      expect(user).to_not be_valid

      expect(user.errors.full_messages).to include 'Recipient number "abcdefg" is not a valid phone number'
    end

    it 'should fail to save if notification sms recipient is blank' do
      user.phone = nil
      user.notifications.build { |n| n.sms 'Test' }
      user.save

      expect(user).to_not be_valid

      expect(user.errors.full_messages).to include 'Recipient cannot be blank'
    end

    it 'should have a non-empty request after delivering sms' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      user.notifications.build { |n| n.sms 'Test' }
      user.save

      expect(user.notifications.last.sms_notifications.last.request.length).to eq(1)
    end

    it 'should increase the size of the sms request array by number of messages - 1 when delivered' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      user.notifications.build do |n|
        n.sms 'Test With Attachment' do
          attach 'https://images.unsplash.com/photo-1436891620584-47fd0e565afb?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&s=df6386c2e327ae9dbc7e5be0bef4e1d6'
          attach '2.jpg'
        end
      end

      expect { user.save }.to change { user.notifications.last.sms_notifications.last.request.length }.from(0).to(2)
    end

    it 'should return false if phone number is not valid' do
      notification = user.notifications.build do |n|
        n.sms 'Test', to: 'abc123'
      end

      expect(notification.sms_notifications.last.valid_phone?).to eq(false)
    end

    it 'should have a non-empty request sms hash after delivering' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      user.notifications.build { |n| n.sms 'Test' }
      user.save

      expect(user.notifications.last.sms_notifications.last.request).to_not be_blank
    end

    it 'should have a non-empty response sms hash after delivering' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      user.notifications.build { |n| n.sms 'Test' }
      user.save

      expect(user.notifications.last.sms_notifications.last.response).to_not be_blank
    end

    it 'should enqueue an sms delivery job when saved' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.sms 'Test With Attachment' do
          attach '1.jpg'
        end
      end

      expect { user.save }.to have_enqueued_job.on_queue('default')
    end

    it 'should deliver an enqueued job' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.sms 'Test With Attachment' do
          attach '1.jpg'
        end
      end

      expect { user.save }.to have_enqueued_job.on_queue('default')

      last_sms_notification = user.notifications.last.sms_notifications.last
      expect(last_sms_notification.request.last).to have_key(:job_id)
      expect(last_sms_notification.sid).to be_nil

      Voltron::SmsJob.perform_now(user.notifications.last.sms_notifications.last)

      expect(user.notifications.last.sms_notifications.last.request.last).to have_key(:StatusCallback)
      expect(user.notifications.last.sms_notifications.last.sid).to_not be_nil
    end

    it 'should accept options for enqueueing a job via deliver_now' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.sms('Test Deliver Now').deliver_now
      end

      expect_any_instance_of(Voltron::SmsJob).to receive(:perform_now)

      user.save
    end

    it 'should accept options for enqueueing a job via deliver_later' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      Voltron.config.notify.use_queue = true
      user.notifications.build do |n|
        n.sms('Test On Specific Later Queue').deliver_later(wait: 10.minutes, queue: 'custom_later')
      end

      expect { user.save }.to have_enqueued_job.on_queue('custom_later')
    end

  end
end