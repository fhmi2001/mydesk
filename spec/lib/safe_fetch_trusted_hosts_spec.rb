require 'rails_helper'

# Custom (MyDesk): SAFE_FETCH_TRUSTED_HOSTS lets named internal services (the WhatsApp Web gateway)
# through the SSRF protection without opening the rest of the private network.
RSpec.describe SafeFetch do
  let(:gateway_url) { 'http://evolution-api:8080/chatwoot/webhook/mydesk-1-abcd' }

  before do
    allow(Resolv).to receive(:getaddresses).and_call_original
    allow(Resolv).to receive(:getaddresses).with('evolution-api').and_return(['172.18.0.5'])
    allow(Resolv).to receive(:getaddresses).with('internal-db').and_return(['10.0.0.9'])
    stub_request(:post, gateway_url).to_return(status: 200, body: '{}')
  end

  def post_to(url)
    # Same options as Webhooks::Trigger
    described_class.fetch(url, method: :post, body: '{}', validate_content_type: false) { nil }
  end

  it 'blocks the gateway by default, as it resolves to a private address' do
    with_modified_env('SAFE_FETCH_TRUSTED_HOSTS' => '') do
      expect { post_to(gateway_url) }.to raise_error(SafeFetch::UnsafeUrlError)
    end
  end

  it 'allows a host listed in SAFE_FETCH_TRUSTED_HOSTS' do
    with_modified_env('SAFE_FETCH_TRUSTED_HOSTS' => 'other-service, Evolution-API') do
      expect { post_to(gateway_url) }.not_to raise_error
    end
  end

  it 'keeps other private hosts blocked' do
    with_modified_env('SAFE_FETCH_TRUSTED_HOSTS' => 'evolution-api') do
      expect { post_to('http://internal-db/') }.to raise_error(SafeFetch::UnsafeUrlError)
    end
  end

  it 'does not follow a redirect from a trusted host to an untrusted one' do
    stub_request(:post, gateway_url).to_return(status: 302, headers: { 'Location' => 'http://internal-db/' })

    with_modified_env('SAFE_FETCH_TRUSTED_HOSTS' => 'evolution-api') do
      expect { post_to(gateway_url) }.to raise_error(SafeFetch::UnsafeUrlError, /not trusted/)
    end
  end
end
