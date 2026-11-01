# Custom (MyDesk): sales reports; employees only ever get their own numbers (Reports::Base), and only administrators export
class Api::V1::Accounts::Crm::ReportsController < Api::V1::Accounts::Crm::BaseController
  def summary = render(json: report(SalesCrm::Reports::Summary).perform)
  def funnel = render(json: report(SalesCrm::Reports::Funnel).perform)
  def agents = render(json: report(SalesCrm::Reports::Agents).perform)
  def lost_reasons = render(json: report(SalesCrm::Reports::LostReasons).perform)
  def timeline = render(json: report(SalesCrm::Reports::Timeline).perform(interval: params[:interval].presence || 'day'))

  # The actual win rate of each stage over the last 12 months, unless a window is given
  def stage_win_rates
    render json: report(SalesCrm::Reports::StageWinRates, from: params[:from].presence || 12.months.ago.to_date.iso8601).perform
  end

  def export
    authorize SalesCrm::Deal, :export?, policy_class: SalesCrm::ReportPolicy
    csv = report(SalesCrm::Reports::Export).perform
    send_data "﻿#{csv}", type: 'text/csv; charset=utf-8', filename: "deals-#{params[:from]}-#{params[:to]}.csv"
  end

  # The reports of SalesCrm::Reports::Catalog: one for both roles, the numbers, then the deals behind any of them
  def show
    render json: catalog_report.perform
  end

  def drill
    render json: catalog_report.drill(page: params[:page])
  end

  private

  def catalog_report
    klass = SalesCrm::Reports::Catalog.fetch(params[:key])
    authorize SalesCrm::Deal, :team?, policy_class: SalesCrm::ReportPolicy if klass.admin_only?
    filters = params.permit(:product_id, :lead_source_id, :stage_id, :days, :full, :group_by, cell: {}).to_h.symbolize_keys
    report(klass, **filters)
  end

  def report(klass, **overrides)
    klass.new(account: Current.account, user: Current.user, from: params[:from], to: params[:to],
              pipeline_id: params[:pipeline_id], assignee_id: params[:assignee_id], **overrides)
  end
end
