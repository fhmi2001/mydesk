# Custom (MyDesk): the Sales section has one currency, set in its general settings (docs/reports/gap-analysis.md,
# decision هـ). It can change only while the account has no deals, since amounts are never converted; every
# pipeline follows it.
module SalesCrm::Currency
  module_function

  def change!(account, code)
    currency = code.to_s.upcase
    raise SalesCrm::ValidationError, I18n.t('sales_crm.errors.invalid_currency') unless SalesCrm::Pipeline::CURRENCIES.include?(currency)
    return currency if currency == account.crm_currency && account.crm_pipelines.where.not(currency: currency).none?
    raise SalesCrm::ValidationError, I18n.t('sales_crm.errors.currency_locked') if locked?(account)

    ActiveRecord::Base.transaction do
      account.update!(crm_default_currency: currency)
      account.crm_pipelines.update_all(currency: currency) # rubocop:disable Rails/SkipsModelValidations
    end
    currency
  end

  def locked?(account)
    account.crm_deals.exists?
  end
end
