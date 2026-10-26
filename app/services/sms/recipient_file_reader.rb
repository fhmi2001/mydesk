# Custom (MyDesk): reads phone numbers from the first column of the first sheet of an uploaded .xlsx or .csv file
class Sms::RecipientFileReader
  SUPPORTED_EXTENSIONS = %w[xlsx csv].freeze
  MAX_FILE_SIZE = 5.megabytes
  MAX_ROWS = 100_000
  NO_DIGITS = /\A[^0-9٠-٩۰-۹]*\z/

  class InvalidFile < StandardError; end

  def initialize(file)
    @file = file
  end

  def numbers
    raise InvalidFile, 'unsupported_format' unless SUPPORTED_EXTENSIONS.include?(extension)
    raise InvalidFile, 'file_too_large' if @file.size > MAX_FILE_SIZE

    values = first_column(Roo::Spreadsheet.open(@file.path, extension: extension.to_sym).sheet(0))
    values.shift if values.first&.match?(NO_DIGITS) # a header such as "phone" or "رقم الجوال"
    values
  rescue Zip::Error, ArgumentError, CSV::MalformedCSVError
    raise InvalidFile, 'unreadable'
  end

  private

  def first_column(sheet)
    return [] if sheet.first_row.nil?

    (sheet.first_row..sheet.last_row).first(MAX_ROWS).filter_map { |row| cell_text(sheet.cell(row, 1)) }
  end

  def extension
    File.extname(@file.original_filename.to_s).delete('.').downcase
  end

  # Excel stores long numbers as floats (966551234567.0); keep their digits, not the decimal part
  def cell_text(value)
    return if value.blank?
    return value.to_i.to_s if value.is_a?(Float) && value == value.floor

    value.to_s
  end
end
