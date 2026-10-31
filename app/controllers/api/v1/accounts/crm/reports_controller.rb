# Custom (MyDesk): sales reports; agents only ever get their own numbers (see Reports::Base)
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
    csv = report(SalesCrm::Reports::Export).perform
    send_data "﻿#{csv}", type: 'text/csv; charset=utf-8', filename: "deals-#{params[:from]}-#{params[:to]}.csv"
  end

  private

  def report(klass, **overrides)
    klass.new(account: Current.account, user: Current.user, from: params[:from], to: params[:to],
              pipeline_id: params[:pipeline_id], assignee_id: params[:assignee_id], **overrides)
  end
end
