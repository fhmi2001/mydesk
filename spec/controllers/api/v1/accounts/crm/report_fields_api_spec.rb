# Custom (MyDesk): the phase 1 endpoints of the sales reports: managed lists, monthly targets, and the settings
# that feed the reports (one currency, stale days, coverage multiple)
require 'rails_helper'

RSpec.describe 'Sales CRM report fields API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm" }
  let(:pipeline) { SalesCrm::Pipelines::EnsureDefault.call(account) }

  before { account.enable_features!('sales_crm') }

  describe 'lists' do
    it 'starts lead sources with the standard entries, and lets only an administrator change a list' do
      get "#{base}/list_items", params: { list: 'lead_source' }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body.map { |i| i['name'] }).to include('الموقع', 'إحالة')

      post "#{base}/list_items", params: { list: 'product', name: 'باقة ذهبية' }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)

      post "#{base}/list_items", params: { list: 'product', name: 'باقة ذهبية' }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body.map { |i| i['name'] }).to eq(['باقة ذهبية'])
    end

    it 'renames, reorders and archives; an archived item leaves the picker but stays on its deals' do
      ids = %w[أ ب].map { |n| SalesCrm::ListItem.create!(account: account, list: 'region', name: n).id }
      patch "#{base}/list_items/#{ids[0]}", params: { name: 'الرياض' }, headers: admin.create_new_auth_token, as: :json
      patch "#{base}/list_items/reorder", params: { list: 'region', ids: ids.reverse }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body.map { |i| i['name'] }).to eq(%w[ب الرياض])

      deal = create(:crm_deal, account: account, pipeline: pipeline, assignee: agent, region_id: ids[0])
      delete "#{base}/list_items/#{ids[0]}", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body.map { |i| i['name'] }).to eq(%w[ب])
      expect(deal.reload.region_id).to eq(ids[0])
    end

    it 'refuses an unknown list' do
      get "#{base}/list_items", params: { list: 'colour' }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'targets' do
    it 'lets an administrator set a month for every employee, and an employee read only their own' do
      put "#{base}/targets", params: { month: '2026-11', amounts: { agent.id => '50000', admin.id => '30000' } },
                             headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['team_cents']).to eq(8_000_000)
      expect(body['targets'].to_h { |t| [t['user_id'], t['amount_cents']] }).to include(agent.id => 5_000_000, admin.id => 3_000_000)

      get "#{base}/targets", params: { month: '2026-11' }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['targets'].map { |t| t['user_id'] }).to eq([agent.id])
      expect(response.parsed_body).not_to have_key('team_cents')

      put "#{base}/targets", params: { month: '2026-11', amounts: { agent.id => '1' } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'settings' do
    it 'keeps the report thresholds and refuses a currency change once deals exist' do
      patch "#{base}/settings", params: { settings: { stale_days: '21', coverage_multiple: '2.5' } },
                                headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('stale_days' => 21, 'coverage_multiple' => 2.5, 'currency_locked' => false)

      create(:crm_deal, account: account, pipeline: pipeline, assignee: agent)
      patch "#{base}/settings", params: { settings: { default_currency: 'USD' } }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      get "#{base}/settings", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('default_currency' => 'SAR', 'currency_locked' => true)
    end

    describe 'conversation settings' do
      let(:inbox) { create(:inbox, account: account) }
      let(:whatsapp) { SalesCrm::ListItem.create!(account: account, list: 'lead_source', name: 'واتساب') }

      it 'starts with 3 silent days and a 14-day SMS window, and keeps what the administrator sets' do
        get "#{base}/settings", headers: admin.create_new_auth_token, as: :json
        expect(response.parsed_body).to include('followup_days' => 3, 'sms_attribution_days' => 14, 'channel_sources' => {})

        patch "#{base}/settings", params: { settings: { followup_days: '5', sms_attribution_days: '30',
                                                        channel_sources: { inbox.id.to_s => whatsapp.id } } },
                                  headers: admin.create_new_auth_token, as: :json
        expect(response.parsed_body).to include('followup_days' => 5, 'sms_attribution_days' => 30,
                                                'channel_sources' => { inbox.id.to_s => whatsapp.id })
        expect(account.reload.crm_lead_source_for_inbox(inbox.id)).to eq(whatsapp)
      end

      it 'keeps the won and lost message suggestions on unless the administrator turns them off' do
        get "#{base}/settings", headers: admin.create_new_auth_token, as: :json
        expect(response.parsed_body).to include('won_lost_messages' => true)
        patch "#{base}/settings", params: { settings: { won_lost_messages: false } }, headers: admin.create_new_auth_token, as: :json
        expect(response.parsed_body).to include('won_lost_messages' => false)
      end

      it 'clears an inbox mapped to nothing' do
        account.update!(crm_channel_sources: { inbox.id.to_s => whatsapp.id })
        patch "#{base}/settings", params: { settings: { channel_sources: { inbox.id.to_s => nil } } },
                                  headers: admin.create_new_auth_token, as: :json
        expect(response.parsed_body['channel_sources']).to eq({})
      end

      it "refuses another account's inbox, an item of another list and days out of range" do
        other_inbox = create(:inbox)
        product = SalesCrm::ListItem.create!(account: account, list: 'product', name: 'باقة')
        [{ channel_sources: { other_inbox.id.to_s => whatsapp.id } }, { channel_sources: { inbox.id.to_s => product.id } },
         { followup_days: '0' }, { sms_attribution_days: '400' }].each do |settings|
          patch "#{base}/settings", params: { settings: settings }, headers: admin.create_new_auth_token, as: :json
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      it 'is for administrators only' do
        patch "#{base}/settings", params: { settings: { followup_days: '5' } }, headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'deals' do
    it 'takes the list values, forecast category and probability, and says what is missing on an open deal' do
      source = SalesCrm::ListItem.create!(account: account, list: 'lead_source', name: 'إحالة')
      post "#{base}/deals", params: { deal: { title: 'x', amount: '100', pipeline_id: pipeline.id } },
                            headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq(I18n.t('sales_crm.errors.close_date_required'))

      post "#{base}/deals", params: { deal: { title: 'x', amount: '100', close_date: Date.current + 9, pipeline_id: pipeline.id,
                                              lead_source_id: source.id, probability_override: '70', forecast_category: 'commit' } },
                            headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('lead_source_id' => source.id, 'probability' => 70, 'forecast_category' => 'commit',
                                              'assignee' => include('id' => agent.id))
    end
  end
end
