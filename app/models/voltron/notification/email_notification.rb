class Voltron::Notification::EmailNotification < ActiveRecord::Base

  belongs_to :notification, inverse_of: :email_notifications

  after_initialize :setup

  before_create :send_now, if: Proc.new { |n| !n.send(:use_queue?) || n.immediate }

  # We have a separate check for +created+ because we trigger +save+ within this callback,
  # and there are known issues of recursion when that is the case. See: https://github.com/rails/rails/issues/14493
  after_commit :send_later, on: :create, if: Proc.new { |n| n.send(:use_queue?) && !n.created }

  validates_presence_of :to, message: I18n.t('voltron.notification.email.to_blank')

  validates_presence_of :subject, message: I18n.t('voltron.notification.email.subject_blank')

  attr_accessor :vars, :attachments

  attr_accessor :created, :immediate

  def request
    Voltron::Notification.format_output_of(request_json)
  end

  def response
    Voltron::Notification.format_output_of(response_json)
  end

  def attach(file, name = nil)
    name = File.basename(file) if name.blank?
    path = file

    if file.is_a?(File)
      path = file.path
      file.close
    elsif !File.exist?(path)
      path = Voltron.asset.find(path) || path
    end

    attachments[name] = path
  end

  def mailer(klass = nil)
    self.mailer_class = (klass || mailer_class).to_s.classify.constantize
  end

  def method(meth = nil)
    self.mailer_method = (meth || mailer_method)
  end

  def arguments(*args)
    @mailer_arguments = *args
  end

  def template(fullpath)
    parts = fullpath.split('/')
    self.template_name = parts.pop.sub(/\.[a-z_]+\.[^\.]+$/i, '')
    self.template_path = parts.join('/')
  end

  def deliver_now
    @delivery_method = :deliver_now
    @immediate = true
  end

  def deliver_now!
    @delivery_method = :deliver_now!
    @immediate = true
  end

  def deliver_later(options={})
    @mail_options = options
    @delivery_method = :deliver_later
  end

  def deliver_later!(options={})
    @mail_options = options
    @delivery_method = :deliver_later!
  end

  private

    def send_now
      mail.send(delivery_method)
      @response << ActionMailer::Base.deliveries.last
      after_deliver
    end

    def send_later
      @response << mail.send(delivery_method, default_options.merge(mail_options))
      after_deliver
    end

    def setup
      @request = []
      @response = []
      @vars ||= {}
      @attachments ||= {}
      @mailer_arguments = nil
      self.mailer_class ||= Voltron.config.notify.default_mailer
      self.mailer_method ||= Voltron.config.notify.default_method
      template(Voltron.config.notify.default_template) if self.template_name.blank? || self.template_path.blank?
    end

    def mail_options
      @mail_options ||= {}
    end

    def delivery_method
      @delivery_method ||= (use_queue? ? :deliver_later : :deliver_now)
    end

    def default_options
      notification.notifyable.class.instance_variable_get('@_notification_defaults').try(:[], :email) || {}
    end

    def after_deliver
      @created = true
      @immediate = nil
      @mail_options = nil
      @delivery_method = nil
      self.request_json = @request.to_json
      self.response_json = @response.to_json
    end

    def use_queue?
      Voltron.config.notify.use_queue
    end

    def mail
      # If no mailer arguments, use default order of arguments as defined in Voltron::NotificationMailer.notify
      if @mailer_arguments.blank?
        @request << { to: to, from: from, subject: subject, template_path: template_path, template_name: template_name }.compact.merge(vars: vars, attachments: attachments)
        @outgoing = mailer.send method, { to: to, from: from, subject: subject, template_path: template_path, template_name: template_name }.compact, vars, attachments
      else
        @request << @mailer_arguments.compact
        @outgoing = mailer.send method, *@mailer_arguments.compact
      end
    end

end