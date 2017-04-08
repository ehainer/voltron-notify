require 'rails_helper'

describe Voltron::NotificationController, type: :controller do

  let(:user) { FactoryGirl.create(:user) }

  context 'Updating existing sms notification' do

    it 'can update an existing sms error code and return 200' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      user.notifications.create { |n| n.sms 'Test Update' }
      sms = user.notifications.last.sms_notifications.last

      expect { post :update, params: { MessageSid: sms.sid, ErrorCode: '123456' } }.to change { sms.reload.error_code }.to('123456')

      expect(response.status).to eq(200)
    end

    it 'can update an existing sms status and return 200' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      user.notifications.create { |n| n.sms 'Test Update' }
      sms = user.notifications.last.sms_notifications.last

      expect { post :update, params: { MessageSid: sms.sid, MessageStatus: 'sent' } }.to change { sms.reload.status }.from('queued').to('sent')

      expect(response.status).to eq(200)
    end

    it 'returns a 404 if an sms with given id is not found' do
      post :update, params: { MessageSid: 'BOLOGNE', MessageStatus: 'sent' }

      expect(response.status).to eq(404)
    end

    it 'return a 422 error if the given sms message cannot be updated' do
      skip 'Set the value of `phone` in the \'user\' factory to run this test' if user.phone.blank?
      user.notifications.create { |n| n.sms 'Test Update' }
      sms = user.notifications.last.sms_notifications.last

      post :update, params: { MessageSid: sms.sid, MessageStatus: 'invalid_status' }

      expect(response.status).to eq(422)
    end

  end

end