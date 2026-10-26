require 'rails_helper'

RSpec.describe Channel::Sms do
  let(:channel) do
    create(:channel_sms, phone_number: 'MyStore', provider: 'deewan', provider_config: { 'api_key' => 'deewan-key' })
  end

  describe '#sender_names' do
    it 'lists the default sender first, then the extra approved names' do
      channel.update!(sender_names: ['MyStore-OTP', ' MyStore-Offers ', '', 'MyStore'])

      expect(channel.sender_names).to eq(%w[MyStore MyStore-OTP MyStore-Offers])
    end

    it 'keeps the API key when the names change' do
      channel.update!(sender_names: ['MyStore-OTP'])

      expect(channel.reload.provider_config).to eq('api_key' => 'deewan-key', 'sender_names' => ['MyStore-OTP'])
    end
  end

  it 'rejects unknown providers' do
    expect(build(:channel_sms, provider: 'unknown')).not_to be_valid
  end
end
