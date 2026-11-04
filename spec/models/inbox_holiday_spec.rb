# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InboxHoliday do
  let(:inbox) { create(:inbox) }

  it 'is valid for a specific date' do
    expect(build(:inbox_holiday, inbox: inbox, day: 25, month: 12, year: 2026)).to be_valid
  end

  it 'is valid for a recurring Feb 29' do
    expect(build(:inbox_holiday, inbox: inbox, day: 29, month: 2, year: nil)).to be_valid
  end

  it 'is invalid for a date that does not exist' do
    holiday = build(:inbox_holiday, inbox: inbox, day: 31, month: 4, year: 2026)

    expect(holiday).not_to be_valid
  end

  it 'does not allow the same date twice in an inbox' do
    create(:inbox_holiday, inbox: inbox, day: 1, month: 1, year: nil)

    expect(build(:inbox_holiday, inbox: inbox, day: 1, month: 1, year: nil)).not_to be_valid
  end

  it 'allows a specific holiday to coexist with a recurring one on the same day' do
    create(:inbox_holiday, inbox: inbox, day: 25, month: 12, year: nil)

    expect(build(:inbox_holiday, inbox: inbox, day: 25, month: 12, year: 2027)).to be_valid
  end

  describe '#occurs_on?' do
    it 'matches a recurring holiday in any year' do
      holiday = build(:inbox_holiday, day: 25, month: 12, year: nil)

      expect(holiday.occurs_on?(Date.new(2030, 12, 25))).to be true
      expect(holiday.occurs_on?(Date.new(2030, 12, 26))).to be false
    end

    it 'matches a specific holiday only in its year' do
      holiday = build(:inbox_holiday, day: 25, month: 12, year: 2026)

      expect(holiday.occurs_on?(Date.new(2026, 12, 25))).to be true
      expect(holiday.occurs_on?(Date.new(2027, 12, 25))).to be false
    end

    it 'matches a recurring Feb 29 only in leap years' do
      holiday = build(:inbox_holiday, day: 29, month: 2, year: nil)

      expect(holiday.occurs_on?(Date.new(2028, 2, 29))).to be true
    end
  end
end
