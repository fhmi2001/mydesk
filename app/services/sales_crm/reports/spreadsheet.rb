# Custom (MyDesk): a report as a file for the manager (CRM_REPORTS_PLAN.md, phase 5). Excel: a summary sheet (what was
# exported — report, question, period, filters, who and when — then the report's numbers: its totals, the period before,
# and each of its tables) and a sheet of the deals (or tasks) behind it. CSV: those deals only, UTF-8 with a BOM so Excel
# reads the Arabic. Both come from the report's own perform and drill, so the file says what the screen says.
require 'csv'
require 'caxlsx'

class SalesCrm::Reports::Spreadsheet
  # What the screens use to link and colour, not numbers to read
  SKIP = %i[cell won_cell key empty team currency period previous_period color group_by interval kinds pipeline_id leak_stage_id
            stage_id assignee_id lead_source_id product_id id avatar_url thumbnail].freeze
  SECTIONS = %i[totals previous_totals team_average rows assignees cards stages buckets sources reasons competitors
                lost_reasons cumulative].freeze
  MAX_PAGES = 40

  attr_reader :report, :title, :filters

  # filters: [[label, value], ...] already named, as the page shows them
  def initialize(report, title:, filters:)
    @report = report
    @title = title
    @filters = filters
  end

  def csv
    rows = items
    columns = item_columns(rows.first)
    body = CSV.generate do |out|
      out << columns.map { |c| label(c) }
      rows.each { |row| out << columns.map { |c| csv_safe(cell_value(c, item_value(row, c))) } }
    end
    "﻿#{body}"
  end

  def xlsx
    package = Axlsx::Package.new
    styles = styles_for(package.workbook)
    package.workbook.add_worksheet(name: t('sheets.summary')) { |sheet| summary(sheet, styles) }
    package.workbook.add_worksheet(name: t('sheets.deals')) { |sheet| deals(sheet, styles) }
    package.to_stream.read
  end

  private

  def t(key, **args) = I18n.t("sales_crm.reports.export.#{key}", **args)
  def rtl? = I18n.locale.to_s.start_with?('ar')
  def data = @data ||= report.perform

  def styles_for(workbook)
    { title: workbook.styles.add_style(b: true, sz: 16), heading: workbook.styles.add_style(b: true, sz: 12, fg_color: '3E3EA8'),
      header: workbook.styles.add_style(b: true, bg_color: 'EEF0FF', border: { style: :thin, color: 'D7DAF5' }),
      label: workbook.styles.add_style(fg_color: '6B7280'), money: workbook.styles.add_style(num_fmt: 4), plain: nil }
  end

  def summary(sheet, styles)
    sheet.sheet_view.right_to_left = rtl?
    add(sheet, [title], styles[:title])
    filters.each { |name, value| add(sheet, [name, value], [styles[:label], nil]) }
    SECTIONS.each do |section|
      value = data[section]
      next if value.blank?

      sheet.add_row []
      add(sheet, [t("sections.#{section}", default: section.to_s.humanize)], styles[:heading])
      value.is_a?(Array) ? table(sheet, value, styles) : pairs(sheet, value, styles)
    end
  end

  # A hash of numbers, one per line (nested ones as «parent / child»)
  def pairs(sheet, hash, styles)
    flatten(hash).each do |key, value|
      add(sheet, [label(key), cell_value(key, value)], [styles[:label], money?(key) ? styles[:money] : nil])
    end
  end

  def table(sheet, rows, styles)
    flat = rows.map { |row| flatten(row) }
    columns = flat.flat_map(&:keys).uniq
    add(sheet, columns.map { |c| label(c) }, styles[:header])
    styles_row = money_styles(columns, styles)
    flat.each { |row| add(sheet, columns.map { |c| cell_value(c, row[c]) }, styles_row) }
  end

  def deals(sheet, styles)
    sheet.sheet_view.right_to_left = rtl?
    rows = items
    columns = item_columns(rows.first)
    add(sheet, columns.map { |c| label(c) }, styles[:header])
    styles_row = money_styles(columns, styles)
    rows.each { |row| add(sheet, columns.map { |c| cell_value(c, item_value(row, c)) }, styles_row) }
  end

  def money_styles(columns, styles) = columns.map { |c| money?(c) ? styles[:money] : nil }

  # Text is always written as text: a deal title starting with «=» must not become a formula
  def add(sheet, values, style)
    sheet.add_row values, style: style, types: values.map { |v| v.is_a?(String) ? :string : nil }
  end

  # The same for CSV, where a cell can only be kept from being read as a formula by a leading apostrophe
  FORMULA_START = /\A[=+\-@\t\r]/

  def csv_safe(value) = value.is_a?(String) && value.match?(FORMULA_START) ? "'#{value}" : value

  # { 'key' => value, 'parent / child' => value }, leaving out what only the screens use
  def flatten(hash, prefix = nil)
    hash.each_with_object({}) do |(key, value), out|
      next if SKIP.include?(key.to_sym)

      name = [prefix, key].compact.join(' / ')
      if value.is_a?(Hash) then out.merge!(flatten(value, name))
      elsif !value.is_a?(Array) then out[name] = value
      end
    end
  end

  # Every page of the deals (or tasks) behind the report, up to MAX_PAGES
  def items
    @items ||= (1..MAX_PAGES).each_with_object([]) do |page, all|
      batch = report.drill(page: page)[:items]
      all.concat(batch)
      break all if batch.size < SalesCrm::Reports::Report::PER_PAGE
    end
  end

  DEAL_COLUMNS = %w[title contact_name assignee stage status amount_cents close_date probability forecast_category won_at lost_at
                    lost_reason days_since_activity days_overdue].freeze
  TASK_COLUMNS = %w[title kind status due_at done_at assignee deal contact].freeze

  def item_columns(first) = first&.key?(:due_at) ? TASK_COLUMNS : DEAL_COLUMNS

  def item_value(row, column)
    value = row[column.to_sym]
    value.is_a?(Hash) ? (value[:name] || value[:title]) : value
  end

  def money?(key) = key.to_s.end_with?('cents')

  def cell_value(key, value)
    return value.to_i / 100.0 if money?(key) && value
    return value.in_time_zone(SalesCrm::Period.zone).strftime('%Y-%m-%d %H:%M') if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    named(key, value)
  end

  def named(key, value)
    return t("values.#{value}", default: value.to_s) if [true, false].include?(value)
    return t("values.#{key}.#{value}", default: value.to_s) if NAMED_VALUES.include?(key.to_s) && value.present?

    value
  end

  # Values the screens show by name (open, commit, call, good…), named the same way in the file
  NAMED_VALUES = %w[status forecast_category kind rating].freeze

  # «parent / child» labels name each part
  def label(key)
    key.to_s.split(' / ').map { |part| t("fields.#{part}", default: part.humanize) }.join(' / ')
  end
end
