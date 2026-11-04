# == Schema Information
#
# Table name: inbox_holidays
#
#  id         :bigint           not null, primary key
#  day        :integer          not null
#  message    :string
#  month      :integer          not null
#  name       :string
#  year       :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint
#  inbox_id   :bigint
#
# Indexes
#
#  index_inbox_holidays_on_account_id  (account_id)
#  index_inbox_holidays_on_inbox_id    (inbox_id)
#
class InboxHoliday < ApplicationRecord
  # Leap year used to validate recurring dates, so Feb 29 is accepted and
  # simply only occurs in leap years.
  REFERENCE_LEAP_YEAR = 2024

  belongs_to :inbox

  before_save :assign_account

  validates :day, presence: true, inclusion: 1..31
  validates :month, presence: true, inclusion: 1..12
  validates :year, inclusion: 1..9999, allow_nil: true
  validates :message, length: { maximum: Limits::OUT_OF_OFFICE_MESSAGE_MAX_LENGTH }
  validates :day, uniqueness: { scope: %i[inbox_id month year] }
  validate :valid_date

  def recurring?
    year.nil?
  end

  def occurs_on?(date)
    day == date.day && month == date.month && (year.nil? || year == date.year)
  end

  private

  def assign_account
    self.account_id = inbox.account_id
  end

  def valid_date
    return if day.blank? || month.blank?
    return if Date.valid_date?(year || REFERENCE_LEAP_YEAR, month, day)

    errors.add(:day, :invalid)
  end
end
