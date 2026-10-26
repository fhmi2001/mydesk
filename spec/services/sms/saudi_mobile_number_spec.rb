require 'rails_helper'

describe Sms::SaudiMobileNumber do
  describe '.normalize' do
    {
      '0551234567' => '966551234567',
      '551234567' => '966551234567',
      '966551234567' => '966551234567',
      '+966551234567' => '966551234567',
      '00966551234567' => '966551234567',
      '+966 55 123 4567' => '966551234567',
      '055-123-4567' => '966551234567',
      '(055) 1234567' => '966551234567',
      '9660551234567' => '966551234567',
      '966551234567.0' => '966551234567',
      '٠٥٥١٢٣٤٥٦٧' => '966551234567',
      '۰۵۵۱۲۳۴۵۶۷' => '966551234567'
    }.each do |raw, expected|
      it "turns #{raw} into #{expected}" do
        expect(described_class.normalize(raw)).to eq(expected)
      end
    end

    ['12345', '0112345678', '966112345678', '+971501234567', '05512345', 'phone', '', nil].each do |raw|
      it "rejects #{raw.inspect}" do
        expect(described_class.normalize(raw)).to be_nil
      end
    end
  end

  describe '.local?' do
    it 'is true only when the country code is missing' do
      expect(described_class.local?('0551234567')).to be true
      expect(described_class.local?('551234567')).to be true
      expect(described_class.local?('966551234567')).to be false
    end
  end
end
