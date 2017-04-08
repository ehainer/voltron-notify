class ApplicationMailer < ActionMailer::Base
  default from: 'no-reply@example.com'
  layout 'mailer'

  def test_mail(to, subject, body)
    @body = body
    mail to: to, subject: subject
  end
end
