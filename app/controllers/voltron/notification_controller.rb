class Voltron::NotificationController < ApplicationController

  skip_before_action :verify_authenticity_token

  def update
    if Voltron::Notification::SmsNotification.exists?(sid: params[:MessageSid])
      sms = Voltron::Notification::SmsNotification.find_by(sid: params[:MessageSid])
      update_params = { status: params[:MessageStatus], error_code: params[:ErrorCode] }.compact
      if sms.update(update_params)
        head :ok
      else
        Voltron.log "(SID: #{params[:MessageSid]}) " + sms.errors.full_messages.join(""), "Notification Update", :light_yellow
        head :unprocessable_entity
      end
    else
      Voltron.log "SMS Notification with id #{params[:MessageSid]} not found.", "Notification Update", :light_yellow
      head :not_found
    end
  end

end
