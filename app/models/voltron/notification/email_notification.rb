class Voltron::Notification::EmailNotification < ActiveRecord::Base

  belongs_to :notification

  after_initialize :setup

  before_create :deliver_now, unless: :use_queue?

  after_create :deliver_later, if: :use_queue?

  validates_presence_of :to, message: I18n.t('voltron.notification.email.to_blank')

  validates_presence_of :subject, message: I18n.t('voltron.notification.email.subject_blank')

  attr_accessor :vars, :attachments

  def setup
    @request = []
    @response = []
    @vars ||= {}
    @attachments ||= {}
    @mailer_arguments = nil
    self.mailer_class ||= Voltron.config.notify.default_mailer
    self.mailer_method ||= Voltron.config.notify.default_method
    template(Voltron.config.notify.default_template)
  end

  def request
    # Wrap entire request in array, for consistency
    Array.wrap({ request: (JSON.parse(request_json) rescue {}) }.with_indifferent_access[:request])
  end

  def response
    # Wrap entire response in array, for consistency
    Array.wrap({ response: (JSON.parse(response_json) rescue {}) }.with_indifferent_access[:response])
  end

  def after_deliver
    self.request_json = @request.to_json
    self.response_json = @response.to_json
  end

  def deliver_now
    mail.deliver_now
    @response << ActionMailer::Base.deliveries.last
    after_deliver
  end

  def deliver_later
    @response << mail.deliver_later(wait: Voltron.config.notify.delay)
    after_deliver
  end

  def attach(file, name = nil)
    name = File.basename(file) if name.blank?
    path = file

    if file.is_a?(File)
      path = file.path
      file.close
    elsif !File.exists?(path)
      path = Voltron.asset.find(path)
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
    parts = fullpath.split("/")
    self.template_name = parts.pop.sub(/\.(html|text)\..*$/, '')
    self.template_path = parts.join('/')
  end

  private

    def use_queue?
      Voltron.config.notify.use_queue
    end

    def mail
      # If no mailer arguments, use default order of arguments as defined in Voltron::NotificationMailer.notify
      if @mailer_arguments.blank?
        @request << { to: to, from: from, subject: subject, template_path: template_path, template_name: template_name }.compact.merge(vars: vars, attachments: attachments)
        mailer.send method, { to: to, from: from, subject: subject, template_path: template_path, template_name: template_name }.compact, vars, attachments
      else
        @request << @mailer_arguments.compact
        mailer.send method, *@mailer_arguments.compact
      end
    end

end