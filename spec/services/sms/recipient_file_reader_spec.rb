require 'rails_helper'

describe Sms::RecipientFileReader do
  def upload(path, name = File.basename(path))
    Rack::Test::UploadedFile.new(path, nil, original_filename: name)
  end

  it 'reads the first column of an Excel file and skips the header row' do
    numbers = described_class.new(upload(Rails.root.join('spec/assets/sms_recipients.xlsx'))).numbers

    expect(numbers).to eq(['0551234567', '551234568', '966551234569', '+966 55 123 4570', '0551234567', '12345',
                           '٠٥٥١٢٣٤٥٧١', '0501234567'])
  end

  it 'reads a CSV file' do
    file = Tempfile.new(['numbers', '.csv'])
    file.write("phone,name\n0551234567,Ahmed\n966551234568,Sara\n")
    file.rewind

    expect(described_class.new(upload(file.path, 'numbers.csv')).numbers).to eq(%w[0551234567 966551234568])
  ensure
    file&.close!
  end

  it 'rejects other file types' do
    expect { described_class.new(upload(Rails.root.join('spec/assets/avatar.png'))).numbers }
      .to raise_error(described_class::InvalidFile, 'unsupported_format')
  end
end
