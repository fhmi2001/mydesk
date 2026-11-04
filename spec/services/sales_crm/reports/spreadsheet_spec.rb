# Custom (MyDesk): the Sales reports as files (CRM_REPORTS_PLAN.md): the Excel summary carries the report's
# numbers and the CSV its deals, so the file says what the screen says; text never turns into a formula.
require 'rails_helper'

RSpec.describe SalesCrm::Reports::Spreadsheet do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:report) { SalesCrm::Reports::PipelineByStage.new(account: account, user: admin) }
  let(:sheet) { described_class.new(report, title: 'الصفقات حسب المرحلة', filters: [%w[الفترة اليوم]]) }

  before do
    create(:crm_deal, account: account, pipeline: pipeline, assignee: agent, title: '=HYPERLINK("x")', amount_cents: 150_000)
    create(:crm_deal, account: account, pipeline: pipeline, assignee: agent, title: 'باقة', amount_cents: 50_000)
  end

  it 'lists the deals behind the report in CSV, in currency units, with formulas defused' do
    rows = CSV.parse(sheet.csv.delete_prefix('﻿'))
    expect(rows.first.first).to eq(I18n.t('sales_crm.reports.export.fields.title'))
    expect(rows.drop(1).map { |r| [r[0], r[5]] }).to eq([["'=HYPERLINK(\"x\")", '1500.0'], %w[باقة 500.0]])
  end

  it 'writes the summary and the deals as an Excel workbook' do
    workbook = Roo::Excelx.new(StringIO.new(sheet.xlsx))
    summary = workbook.sheet(0)
    expect(summary.row(1).first).to eq('الصفقات حسب المرحلة')
    expect(summary.row(2).first(2)).to eq(%w[الفترة اليوم])
    totals = (1..summary.last_row).map { |i| summary.row(i) }.find { |r| r.first == I18n.t('sales_crm.reports.export.fields.total_cents') }
    expect(totals.second).to eq(2000.0)
    deals = workbook.sheet(1)
    expect(deals.row(2).first).to eq('=HYPERLINK("x")') # kept as text
    expect(deals.last_row).to eq(3)
  end
end
