require 'rails_helper'

RSpec.describe 'SMS campaign recipients preview API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v1/accounts/#{account.id}/campaigns/sms_recipients/preview" }

  it 'rejects agents' do
    post path, headers: agent.create_new_auth_token, params: { numbers: '0551234567' }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'cleans typed and uploaded numbers together' do
    file = Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/sms_recipients.xlsx'))

    post path, headers: admin.create_new_auth_token, params: { numbers: "0559999999\n0551234567،abc", file: file }

    body = response.parsed_body
    expect(response).to have_http_status(:success)
    expect(body['valid_count']).to eq(7)
    expect(body['duplicate_count']).to eq(2)
    expect(body['invalid_count']).to eq(2)
    expect(body['valid_numbers']).to include('966559999999', '966551234571', '966501234567')
  end

  it 'counts contacts of the chosen labels without cleaning their numbers' do
    label = create(:label, account: account)
    create(:contact, account: account, phone_number: '+971501234567').update_labels([label.title])
    create(:contact, account: account).update_labels([label.title])

    post path, headers: admin.create_new_auth_token, params: { label_ids: [label.id] }, as: :json

    expect(response.parsed_body).to include('label_recipients_count' => 1, 'valid_count' => 0)
  end

  it 'explains unreadable files' do
    file = Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/avatar.png'))

    post path, headers: admin.create_new_auth_token, params: { file: file }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('unsupported_format')
  end
end
