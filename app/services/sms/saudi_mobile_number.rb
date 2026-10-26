# Custom (MyDesk): turns how people write Saudi mobile numbers into the 9665XXXXXXXX form SMS gateways expect.
# Accepts 05XXXXXXXX, 5XXXXXXXX, 9665XXXXXXXX, +966…, 00966…, spaces/dashes/brackets and Arabic-Indic digits.
module Sms::SaudiMobileNumber
  COUNTRY_CODE = '966'.freeze
  VALID_FORMAT = /\A9665\d{8}\z/
  LOCAL_WITH_ZERO = /\A05\d{8}\z/
  LOCAL_WITHOUT_ZERO = /\A5\d{8}\z/
  CODE_WITH_LOCAL_ZERO = /\A9660(5\d{8})\z/
  # Arabic-Indic (٠-٩) and Eastern Arabic-Indic (۰-۹) digits
  INDIC_DIGITS = ('٠'..'٩').to_a.join + ('۰'..'۹').to_a.join
  ASCII_DIGITS = ('0'..'9').to_a.join * 2

  module_function

  # Returns the normalized number, or nil when it cannot be a Saudi mobile number
  def normalize(raw)
    digits = clean(raw)
    return unless digits

    digits = "#{COUNTRY_CODE}#{digits[1..]}" if digits.match?(LOCAL_WITH_ZERO)
    digits = "#{COUNTRY_CODE}#{digits}" if digits.match?(LOCAL_WITHOUT_ZERO)
    digits = "#{COUNTRY_CODE}#{Regexp.last_match(1)}" if digits.match(CODE_WITH_LOCAL_ZERO)
    digits if digits.match?(VALID_FORMAT)
  end

  # True when the number was written without the country code (05… or 5…)
  def local?(raw)
    digits = clean(raw)
    digits.present? && (digits.match?(LOCAL_WITH_ZERO) || digits.match?(LOCAL_WITHOUT_ZERO))
  end

  # ASCII digits only, without "+"/"00" and separators; nil when anything else is left
  def clean(raw)
    digits = raw.to_s.strip.tr(INDIC_DIGITS, ASCII_DIGITS)
    digits = digits.delete_suffix('.0') # spreadsheets often store numbers as floats
    digits = digits.gsub(/[\s\-().]/, '').sub(/\A(\+|00)/, '')
    digits if digits.match?(/\A\d+\z/)
  end
end
