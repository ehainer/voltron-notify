require "twilio-ruby"

class Voltron::Notification::SmsNotification < ActiveRecord::Base

  include Rails.application.routes.url_helpers

  has_many :attachments

  belongs_to :notification

  after_initialize :setup

  before_create :deliver_now, unless: :use_queue?

  after_create :deliver_later, if: :use_queue?

  validates :status, presence: false, inclusion: { in: %w( accepted queued sending sent delivered received failed undelivered unknown ), message: 'must be one of: accepted, queued, sending, sent, delivered, received, failed, undelivered, or unknown' }, on: :update

  def setup
    @request = []
    @response = []
  end

  def request
    # Ensure returned object is an array, whose containing hashes all have symbolized keys, for consistency
    out = Array.wrap((JSON.parse(request_json) rescue nil)).compact
    out.each { |i| i.try(:deep_symbolize_keys!) }
    out
  end

  def response
    # Ensure returned object is an array, whose containing hashes all have symbolized keys, for consistency
    out = Array.wrap((JSON.parse(response_json) rescue nil)).compact
    out.each { |i| i.try(:deep_symbolize_keys!) }
    out
  end

  def after_deliver
    self.request_json = @request.to_json
    self.response_json = @response.to_json
    self.sid = response.first.try(:[], :sid)
    self.status = response.first.try(:[], :status) || 'unknown'

    # if use_queue?, meaning if this was sent via ActiveJob, we need to save ourself
    # since we got to here within after_create, meaning setting the attributes alone won't cut it
    self.save if use_queue?
  end

  def deliver_now
    all_attachments = attachments.map(&:attachment)

    # If sending more than 1 attachment, iterate through all but one attachment and send each without a body...
    if all_attachments.count > 1
      begin
        client.messages.create({ from: from_formatted, to: to_formatted, media_url: all_attachments.shift, status_callback: callback_url }.compact)
        @request << Rack::Utils.parse_nested_query(client.last_request.body)
        @response << JSON.parse(client.last_response.body)
      end until all_attachments.count == 1
    end

    # ... Then send the last attachment (if any) with the actual text body. This way we're not sending multiple SMS's with same body
    client.messages.create({ from: from_formatted, to: to_formatted, body: message, media_url: all_attachments.shift, status_callback: callback_url }.compact)
    @request << Rack::Utils.parse_nested_query(client.last_request.body)
    @response << JSON.parse(client.last_response.body)
    after_deliver
  end

  def deliver_later
    job = Voltron::SmsJob.set(wait: Voltron.config.notify.delay).perform_later self
    @request << job
    @response << { sid: nil, status: 'unknown' }
    after_deliver
  end

  def attach(url)
    if url.starts_with? 'http'
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
      Voltron.log e.message, 'Notify', :light_red
      false
    end
  end

  # TODO: Move this to actual validates_* methods
  def error_messages
    output = []
    output << 'recipient cannot be blank' if to.blank?
    output << 'recipient is not a valid phone number' unless valid_phone?
    output << 'sender cannot be blank' if from.blank?
    output << 'message cannot be blank' if message.blank?
    output
  end

  def callback_url
    url = try(:update_voltron_notification_url, host: Voltron.config.base_url).to_s
    # Don't allow local or blank urls
    return nil if url.include?('localhost') || url.include?('127.0.0.1') || url.blank?
    url
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
