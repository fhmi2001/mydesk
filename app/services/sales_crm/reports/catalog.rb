# Custom (MyDesk): the reports of CRM_REPORTS_PLAN.md phase 4, by the key the API serves them under
# (GET crm/reports/:key and crm/reports/:key/deals). Wave أ: reports 1 to 7; wave ب: 8, 10, 12, 14, 15, 16 and 19;
# wave ج: 9, 11, 13, 17 and 18. Conversations and sales (CONVERSATION_SALES_PLAN.md, phase 4): 20, 21 and 22.
module SalesCrm::Reports::Catalog
  REPORTS = [
    SalesCrm::Reports::PipelineByStage, SalesCrm::Reports::Closing, SalesCrm::Reports::Stale, SalesCrm::Reports::MyTasks,
    SalesCrm::Reports::WonLost, SalesCrm::Reports::Quota, SalesCrm::Reports::ForecastCategories,
    SalesCrm::Reports::Coverage, SalesCrm::Reports::WinRates, SalesCrm::Reports::Losses, SalesCrm::Reports::Activity,
    SalesCrm::Reports::NewDeals, SalesCrm::Reports::DataQuality, SalesCrm::Reports::Scorecard,
    SalesCrm::Reports::Conversion, SalesCrm::Reports::Cycle, SalesCrm::Reports::Changes, SalesCrm::Reports::Revenue,
    SalesCrm::Reports::DealSize, SalesCrm::Reports::ResponseSpeed, SalesCrm::Reports::Campaigns, SalesCrm::Reports::ConversationDeals
  ].index_by { |klass| klass::KEY }.freeze

  module_function

  def keys = REPORTS.keys

  def fetch(key) = REPORTS.fetch(key.to_s)
end
