# Custom (MyDesk): makes Arabic and English text comparable for search: no diacritics or tatweel, one form
# for alef / taa marbuta / alef maqsura, Western digits, lower case, single spaces.
module SalesCrm::Normalize
  DIACRITICS = /[ؐ-ًؚ-ٰٟۖ-ۭـ]/
  ARABIC_DIGITS = { '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4', '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
                    '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4', '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9' }.freeze
  LETTERS = { 'أ' => 'ا', 'إ' => 'ا', 'آ' => 'ا', 'ٱ' => 'ا', 'ة' => 'ه', 'ى' => 'ي', 'ؤ' => 'و', 'ئ' => 'ي' }.freeze

  module_function

  def text(value)
    s = value.to_s.unicode_normalize(:nfkc).gsub(DIACRITICS, '')
    s = s.gsub(/[٠-٩۰-۹]/, ARABIC_DIGITS).gsub(/[أإآٱةىؤئ]/, LETTERS)
    s.downcase.squish
  end

  # Looser than text: also drops the definite article so «السعر مرتفع» and «سعر مرتفع» group together
  def loose(value)
    text(value).split.map { |w| w.length > 3 && w.start_with?('ال') ? w[2..] : w }.join(' ')
  end

  def digits(value)
    value.to_s.gsub(/[٠-٩۰-۹]/, ARABIC_DIGITS)
  end
end
