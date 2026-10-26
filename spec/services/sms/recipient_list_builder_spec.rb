require 'rails_helper'

describe Sms::RecipientListBuilder do
  it 'cleans numbers, drops duplicates and reports rejected ones' do
    result = described_class.new(['0551234567', '966551234567', '551234568', 'abc', '', '12345']).perform

    expect(result.valid_numbers).to eq(%w[966551234567 966551234568])
    expect(result.duplicate_count).to eq(1)
    expect(result.invalid_count).to eq(2)
    expect(result.invalid_samples).to eq(%w[abc 12345])
    expect(result.country_code_added_count).to eq(2)
  end

  it 'returns the counts the review page needs' do
    json = described_class.new(['0551234567']).perform.as_json

    expect(json).to include(valid_numbers: ['966551234567'], valid_count: 1, duplicate_count: 0, invalid_count: 0)
  end
end
