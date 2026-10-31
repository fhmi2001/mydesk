# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Normalize do
  it 'strips diacritics and unifies alef forms' do
    expect(described_class.text('أَحْمَد')).to eq('احمد')
    expect(described_class.text('إبراهيم آل')).to eq('ابراهيم ال')
  end

  it 'unifies taa marbuta and alef maqsura' do
    expect(described_class.text('فاطمة')).to eq('فاطمه')
    expect(described_class.text('مصطفى')).to eq('مصطفي')
  end

  it 'converts Arabic-Indic digits and strips tatweel' do
    expect(described_class.text('باقة ٥٠ ألف')).to eq('باقه 50 الف')
    expect(described_class.text('مـــحـمـد')).to eq('محمد')
  end

  it 'lowercases and squishes' do
    expect(described_class.text('  Ahmed   Ali ')).to eq('ahmed ali')
    expect(described_class.text(nil)).to eq('')
  end

  it 'digits converts only the digits' do
    expect(described_class.digits('٥٠٬٠٠٠٫٥')).to eq('50٬000٫5')
  end
end
