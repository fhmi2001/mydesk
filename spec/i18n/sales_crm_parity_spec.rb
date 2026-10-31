# Custom (MyDesk): the Sales CRM ships in Arabic and English at the same depth: every key exists in both
require 'rails_helper'

RSpec.describe 'Sales CRM translations parity' do # rubocop:disable RSpec/DescribeClass -- files, not a class
  def flatten(hash, prefix = nil)
    hash.flat_map do |key, value|
      full = [prefix, key].compact.join('.')
      value.is_a?(Hash) ? flatten(value, full) : [full]
    end
  end

  it 'dashboard crm.json has identical keys in ar and en' do
    en = JSON.parse(Rails.root.join('app/javascript/dashboard/i18n/locale/en/crm.json').read)
    ar = JSON.parse(Rails.root.join('app/javascript/dashboard/i18n/locale/ar/crm.json').read)
    expect(flatten(ar).sort).to eq(flatten(en).sort)
  end

  it 'server sales_crm yml has identical keys in ar and en' do
    en = YAML.safe_load(Rails.root.join('config/locales/sales_crm.en.yml').read)['en']
    ar = YAML.safe_load(Rails.root.join('config/locales/sales_crm.ar.yml').read)['ar']
    expect(flatten(ar).sort).to eq(flatten(en).sort)
  end

  it 'notification title and feature strings exist in both languages' do
    expect(I18n.t('notifications.notification_title.crm_task_due', locale: :ar, title: 'x')).to include('x')
    expect(I18n.t('notifications.notification_title.crm_task_due', locale: :en, title: 'x')).to include('x')
  end
end
