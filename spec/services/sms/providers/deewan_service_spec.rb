require 'rails_helper'

describe Sms::Providers::DeewanService do
  let!(:sms_channel) do
    create(:channel_sms, phone_number: 'MyStore', provider: 'deewan', provider_config: { 'api_key' => 'deewan-key' })
  end
  let!(:contact_inbox) { create(:contact_inbox, inbox: sms_channel.inbox, source_id: '+966500000001') }
  let!(:conversation) { create(:conversation, contact_inbox: contact_inbox, inbox: sms_channel.inbox) }
  let(:api_url) { 'https://apis.deewan.sa/sms/v1/messages' }
  let(:success_body) do
    { replyCode: 0, replyMessage: 'Request handled successfully', requestId: 'req-123',
      data: { SentSMSIDs: [{ SMSId: '0461f8f4-4c4f-4dc0-b7ed-097f4f9f85f4' }], InvalidRecipients: '' } }.to_json
  end

  describe 'sending a conversation reply' do
    it 'posts to Deewan and stores the returned SMS id on the message' do
      request = stub_request(:post, api_url)
                .with(
                  headers: { 'Authorization' => 'Bearer deewan-key', 'Content-Type' => 'application/json' },
                  body: { messageText: 'Hello', senderName: 'MyStore', messageType: 'text', recipients: '966500000001' }.to_json
                )
                .to_return(status: 200, body: success_body, headers: { 'Content-Type' => 'application/json' })
      message = create(:message, message_type: :outgoing, content: 'Hello', conversation: conversation)

      Sms::SendOnSmsService.new(message: message).perform

      expect(request).to have_been_requested
      expect(message.reload.source_id).to eq('0461f8f4-4c4f-4dc0-b7ed-097f4f9f85f4')
    end

    it 'sends Arabic text as unicode' do
      request = stub_request(:post, api_url)
                .with(body: hash_including('messageText' => 'مرحباً'.encode('UTF-16BE').unpack1('H*').upcase,
                                           'messageType' => 'unicode'))
                .to_return(status: 200, body: success_body, headers: { 'Content-Type' => 'application/json' })
      message = create(:message, message_type: :outgoing, content: 'مرحباً', conversation: conversation)

      Sms::SendOnSmsService.new(message: message).perform

      expect(request).to have_been_requested
    end

    it 'marks the message as failed when Deewan rejects it' do
      stub_request(:post, api_url)
        .to_return(status: 200, body: { replyCode: -17, replyMessage: 'Not enough credits' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
      message = create(:message, message_type: :outgoing, content: 'Hello', conversation: conversation)

      Sms::SendOnSmsService.new(message: message).perform

      expect(message.reload.status).to eq('failed')
      expect(message.external_error).to eq('Not enough credits')
    end
  end

  describe '#send_text_message' do
    it 'returns the SMS id and request id for campaign messages' do
      stub_request(:post, api_url).to_return(status: 200, body: success_body, headers: { 'Content-Type' => 'application/json' })

      receipt = sms_channel.send_text_message('+966500000002', 'Sale today')

      expect(receipt.message_id).to eq('0461f8f4-4c4f-4dc0-b7ed-097f4f9f85f4')
      expect(receipt.request_id).to eq('req-123')
    end

    it 'raises with the detailed reason and request id when Deewan rejects a campaign message' do
      body = { replyCode: -1, replyMessage: 'Bad Request', requestId: 'req-456',
               error: { internalErrors: [{ code: -17, details: 'Invalid Unicode data!' }] } }.to_json
      stub_request(:post, api_url).to_return(status: 400, body: body, headers: { 'Content-Type' => 'application/json' })

      expect { sms_channel.send_text_message('+966500000002', 'Sale today') }
        .to raise_error(described_class::DeliveryError, 'Invalid Unicode data! (-17)') { |error| expect(error.request_id).to eq('req-456') }
    end

    it 'sends from the sender name the campaign picked' do
      request = stub_request(:post, api_url)
                .with(body: hash_including('senderName' => 'MyStore-OTP'))
                .to_return(status: 200, body: success_body, headers: { 'Content-Type' => 'application/json' })

      sms_channel.send_text_message('+966500000002', 'your otp is 01234', sender_name: 'MyStore-OTP')

      expect(request).to have_been_requested
    end
  end
end
