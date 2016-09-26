require "twilio-ruby"

class Voltron::Notification::SmsNotification < ActiveRecord::Base

  has_many :attachments

  belongs_to :notification

  after_initialize :setup

  before_create :deliver_now, unless: :use_queue?

  after_create :deliver_later, if: :use_queue?

  include Rails.application.routes.url_helpers

  def setup
    @request = []
    @response = []
  end

  def request
    # Wrap entire request in container hash so that we can call deep_symbolize_keys on it (in case it's an array)
    # Wrap entire request in array and flatten so we can be sure the result is an array
    [{ request: (JSON.parse(request_json) rescue nil) }.deep_symbolize_keys[:request]].flatten.compact
  end

  def response
    # Wrap entire response in container hash so that we can call deep_symbolize_keys on it (in case it's an array)
    # Wrap entire response in array and flatten so we can be sure the result is an array
    [{ response: (JSON.parse(response_json) rescue nil) }.deep_symbolize_keys[:response]].flatten.compact
  end

  def after_deliver
    if use_queue?
      # if use_queue?, meaning if this was sent via ActiveJob, we need to update ourself
      # since we got to here within after_create, meaning setting the attributes alone won't cut it
      self.update(request_json: @request.to_json, response_json: @response.to_json, sid: @response.first[:sid], status: @response.first[:status])
    else
      # We are before_create so we can just set the attribute values, it will be saved after this
      self.request_json = @request.to_json
      self.response_json = @response.to_json
      self.sid = @response.first[:sid]
      self.status = @response.first[:status]
    end
  end

  def deliver_now
    all_attachments = attachments.map(&:attachment)

    # If sending more than 1 attachment, iterate through all but one attachment and send each without a body...
    if all_attachments.count > 1
      begin
        client.messages.create({ from: from_formatted, to: to_formatted, media_url: all_attachments.shift }.compact)
        @request << Rack::Utils.parse_nested_query(client.last_request.body)
        @response << JSON.parse(client.last_response.body)
      end until all_attachments.count == 1
    end

    # ... Then send the last attachment (if any) with the actual text body. This way we're not sending multiple SMS's with same body
    client.messages.create({ from: from_formatted, to: to_formatted, body: message, media_url: all_attachments.shift }.compact)
    @request << Rack::Utils.parse_nested_query(client.last_request.body)
    @response << JSON.parse(client.last_response.body)
    after_deliver
  end

  def deliver_later
    job = Voltron::SmsJob.set(wait: Voltron.config.notify.delay).perform_later self
    @request << job.to_json
    @response << { sid: nil, status: "enqueued" }
    after_deliver
  end

  def attach(url)
    if url.starts_with? "http"
      attachments.build attachment: url
    else
      attachments.build attachment: Voltron.config.base_url + ActionController::Base.helpers.asset_url(url)
    end
  end

  def valid_phone?
    begin
      return true if to.blank? # Handle a blank `to` separately in the errors method below
      to_formatted
      true
    rescue => e
      Voltron.log e.message, "Notify", :light_red
      false
    end
  end

  # TODO: Move this to actual validates_* methods
  def error_messages
    output = []
    output << "recipient cannot be blank" if to.blank?
    output << "recipient is not a valid phone number" unless valid_phone?
    output << "sender cannot be blank" if from.blank?
    output << "message cannot be blank" if message.blank?
    output
  end

  private

    def use_queue?
      Voltron.config.notify.use_queue
    end

    def to_formatted
      format to
    end

    def from_formatted
      format from
    end

    def format(input)
      # Try to format the number via Twilio's api
      # raises an exception if the input was invalid
      number = lookup.phone_numbers.get input
      number.phone_number
    end

    def client
      @client ||= ::Twilio::REST::Client.new Voltron.config.notify.sms_account_sid, Voltron.config.notify.sms_auth_token
    end

    def lookup
      @lookup ||= ::Twilio::REST::LookupsClient.new Voltron.config.notify.sms_account_sid, Voltron.config.notify.sms_auth_token
    end

end
