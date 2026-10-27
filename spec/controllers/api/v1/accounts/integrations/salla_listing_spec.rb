require 'rails_helper'

RSpec.describe 'Salla in the integrations list', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  it 'is listed even before the Salla app keys are set, and says so' do
    allow(Salla::Config).to receive(:configured?).and_return(false)

    get "/api/v1/accounts/#{account.id}/integrations/apps", headers: admin.create_new_auth_token, as: :json

    salla = response.parsed_body['payload'].find { |app| app['id'] == 'salla' }
    expect(salla).to include('configured' => false, 'enabled' => false)
  end

  it 'reports when the keys are set' do
    allow(Salla::Config).to receive(:configured?).and_return(true)

    get "/api/v1/accounts/#{account.id}/integrations/apps/salla", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to include('configured' => true)
  end
end
