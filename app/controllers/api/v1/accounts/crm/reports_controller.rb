# Custom (MyDesk): sales reports; agents only ever get their own numbers (see Reports::Base)
class Api::V1::Accounts::Crm::ReportsController < Api::V1::Accounts::Crm::BaseController
  def summary = render(json: report(SalesCrm::Reports::Summary).perform)
  def funnel = render(json: report(SalesCrm::Reports::Funnel).perform)
  def agents = render(json: report(SalesCrm::Reports::Agents).perform)
  def lost_reasons = render(json: report(SalesCrm::Reports::LostReasons).perform)
  def timeline = render(json: report(SalesCrm::Reports::Timeline).perform(interval: params[:interval].presence || 'day'))

  def export
    csv = report(SalesCrm::Reports::Export).perform
    send_data "﻿#{csv}", type: 'text/csv; charset=utf-8', filename: "deals-#{params[:from]}-#{params[:to]}.csv"
  end

  private

  def report(klass)
    klass.new(account: Current.account, user: Current.user, from: params[:from], to: params[:to],
              pipeline_id: params[:pipeline_id], assignee_id: params[:assignee_id])
  end
end
