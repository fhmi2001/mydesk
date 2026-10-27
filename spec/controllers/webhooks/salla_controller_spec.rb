require 'rails_helper'

RSpec.describe 'Salla webhooks', type: :request do
  let(:secret) { 'webhook-secret' }
  let!(:hook) { create(:integrations_hook, app_id: 'salla', reference_id: '555', settings: { 'refresh_token' => 'r' }) }
  let(:order_created) do
    { event: 'order.created', merchant: 555, created_at: '2026-10-26 12:00:00',
      data: { id: 9001, reference_id: 70_001, status: { id: 1, name: 'بإنتظار المراجعة', slug: 'under_review' },
              customer: { id: 7, first_name: 'سارة', last_name: 'محمد', mobile: 555_123_456, mobile_code: '+966' } } }
  end

  before { allow(Salla::Config).to receive(:webhook_secret).and_return(secret) }

  def deliver(payload, signature: nil)
    body = payload.to_json
    post '/webhooks/salla', params: body,
                            headers: { 'Content-Type' => 'application/json',
                                       'X-Salla-Signature' => signature || OpenSSL::HMAC.hexdigest('SHA256', secret, body) }
  end

  it 'rejects requests without a valid signature' do
    deliver(order_created, signature: 'forged')

    expect(response).to have_http_status(:unauthorized)
    expect(SallaEvent.count).to eq(0)
  end

  it 'logs order events for the account that connected the store' do
    deliver(order_created)

    expect(response).to have_http_status(:ok)
    expect(hook.account.salla_events.last).to have_attributes(
      event: 'order.created', order_id: '9001', order_reference: '70001', status_name: 'بإنتظار المراجعة',
      customer_name: 'سارة محمد', customer_mobile: '+966555123456'
    )
  end

  it 'reads the order of status updates' do
    deliver({ event: 'order.status.updated', merchant: 555,
              data: { order: { id: 9001, reference_id: 70_001, customer: { first_name: 'سارة' } }, status: 'تم التنفيذ' } })

    expect(SallaEvent.last).to have_attributes(event: 'order.status.updated', order_id: '9001', status_name: 'تم التنفيذ')
  end

  it 'ignores stores that are not connected' do
    deliver(order_created.merge(merchant: 999))

    expect(response).to have_http_status(:ok)
    expect(SallaEvent.count).to eq(0)
  end

  it 'removes the connection when the merchant uninstalls the app' do
    deliver({ event: 'app.uninstalled', merchant: 555, data: {} })

    expect(Integrations::Hook.exists?(hook.id)).to be(false)
  end

  it 'stores tokens Salla sends on app.store.authorize' do
    deliver({ event: 'app.store.authorize', merchant: 555,
              data: { access_token: 'easy-access', refresh_token: 'easy-refresh', expires: 14.days.from_now.to_i } })

    expect(hook.reload.access_token).to eq('easy-access')
    expect(hook.settings['refresh_token']).to eq('easy-refresh')
  end
end
