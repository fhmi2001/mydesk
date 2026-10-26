# Custom (MyDesk): cleans a raw list of phone numbers for an SMS campaign.
# Normalizes Saudi mobiles (adding 966 when missing), drops duplicates and reports what was rejected and why.
class Sms::RecipientListBuilder
  INVALID_SAMPLE_SIZE = 50

  Result = Struct.new(:valid_numbers, :duplicate_count, :invalid_count, :invalid_samples, :country_code_added_count,
                      keyword_init: true) do
    def as_json(*)
      {
        valid_numbers: valid_numbers,
        valid_count: valid_numbers.size,
        duplicate_count: duplicate_count,
        invalid_count: invalid_count,
        invalid_samples: invalid_samples,
        country_code_added_count: country_code_added_count
      }
    end
  end

  def initialize(raw_numbers)
    @raw_numbers = Array(raw_numbers).map { |value| value.to_s.strip }.compact_blank
  end

  def perform
    valid = []
    invalid = []
    country_code_added = 0

    @raw_numbers.each do |raw|
      number = Sms::SaudiMobileNumber.normalize(raw)
      next invalid << raw if number.nil?

      country_code_added += 1 if Sms::SaudiMobileNumber.local?(raw)
      valid << number
    end

    unique = valid.uniq
    Result.new(valid_numbers: unique, duplicate_count: valid.size - unique.size, invalid_count: invalid.size,
               invalid_samples: invalid.first(INVALID_SAMPLE_SIZE), country_code_added_count: country_code_added)
  end
end
