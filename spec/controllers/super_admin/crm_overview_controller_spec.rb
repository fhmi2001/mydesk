# Custom (MyDesk)
require 'rails_helper'

RSpec.describe 'Super Admin CRM overview', type: :request do # -- request spec
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account, name: 'عيادة النور') }
  let(:other) { create(:account, name: 'ورشة السرعة') }

  before do
    account.enable_features!('sales_crm')
    create(:crm_deal, account: account, title: 'باقة ذهبية', amount_cents: 5_000_000)
    create(:crm_deal, account: other, title: 'صيانة', amount_cents: 20_000, status: :won, won_at: Time.current)
  end

  it 'requires a super admin' do
    get '/super_admin/crm_overview'
    expect(response).to have_http_status(:redirect)
  end

  context 'when signed in' do
    before { sign_in(super_admin, scope: :super_admin) }

    it 'lists accounts with their flag status and counts' do
      get '/super_admin/crm_overview'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('عيادة النور').and include('ورشة السرعة')
      expect(response.body).to include('Enabled for 1 account')
    end

    it 'filters deals by account and status and shows totals' do
      get '/super_admin/crm_overview/deals', params: { status: 'won' }
      expect(response.body).to include('صيانة')
      expect(response.body).not_to include('باقة ذهبية')
      get '/super_admin/crm_overview/deals', params: { account_id: account.id }
      expect(response.body).to include('باقة ذهبية')
      expect(response.body).not_to include('صيانة')
    end

    it 'writes an audit line for every view' do
      allow(Rails.logger).to receive(:info).and_call_original
      get '/super_admin/crm_overview/deals', params: { account_id: account.id }
      expect(Rails.logger).to have_received(:info)
        .with(a_string_including("[CRM audit] super_admin=#{super_admin.id} view=deals account_id=#{account.id}"))
      deal = SalesCrm::Deal.find_by(title: 'باقة ذهبية')
      get "/super_admin/crm_overview/deals/#{deal.id}"
      expect(response.body).to include('باقة ذهبية')
      expect(Rails.logger).to have_received(:info).with(a_string_including("view=deal account_id=#{account.id} id=#{deal.id}"))
    end
  end
end
