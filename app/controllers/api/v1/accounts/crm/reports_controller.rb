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

  # A report as Excel (its numbers and its deals) or CSV (its deals, or those behind one number with `cell`), for
  # administrators. `heading` carries what the page shows above the report (its name, period and filters).
  def download
    authorize SalesCrm::Deal, :export?, policy_class: SalesCrm::ReportPolicy
    sheet = SalesCrm::Reports::Spreadsheet.new(catalog_report, title: heading.first&.last.to_s, filters: heading + exported)
    name = "#{params[:key]}-#{params[:from]}-#{params[:to]}".delete_suffix('--')
    if params[:file_format] == 'csv'
      send_data sheet.csv, type: 'text/csv; charset=utf-8', filename: "#{name}.csv"
    else
      send_data sheet.xlsx, type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', filename: "#{name}.xlsx"
    end
  end

  private

  # [[label, value], ...] from the page (a JSON list of { label, value }), at most 20 short lines
  def heading
    lines = JSON.parse(params[:heading].to_s)
    return [] unless lines.is_a?(Array)

    lines.first(20).filter_map do |line|
      [line['label'].to_s.first(100), line['value'].to_s.first(200)] if line.is_a?(Hash)
    end
  rescue JSON::ParserError
    []
  end

  def exported
    [[I18n.t('sales_crm.reports.export.filters.exported_at'), Time.current.in_time_zone(SalesCrm::Period.zone).strftime('%Y-%m-%d %H:%M')],
     [I18n.t('sales_crm.reports.export.filters.exported_by'), Current.user.available_name]]
  end

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
