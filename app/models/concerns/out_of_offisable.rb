# frozen_string_literal: true

module OutOfOffisable
  extend ActiveSupport::Concern

  OFFISABLE_ATTRS = %w[day_of_week closed_all_day open_hour open_minutes close_hour close_minutes open_all_day].freeze
  HOLIDAY_ATTRS = %w[name message day month year].freeze
  DEFAULT_WORKING_HOURS = [
    { day_of_week: 0, closed_all_day: true, open_all_day: false },
    { day_of_week: 1, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 2, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 3, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 4, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 5, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 6, closed_all_day: true, open_all_day: false }
  ].map(&:freeze).freeze

  included do
    has_many :working_hours, dependent: :destroy_async
    has_many :inbox_holidays, dependent: :destroy_async
    after_create :create_default_working_hours
  end

  def out_of_office?
    working_hours_enabled? && (holiday_today.present? || working_hours.today.closed_now?)
  end

  # A specific (one-off) holiday wins over a recurring one on the same day,
  # so a special message can be set for a single year.
  def holiday_on(date)
    matches = inbox_holidays.select { |holiday| holiday.occurs_on?(date) }
    matches.find { |holiday| !holiday.recurring? } || matches.first
  end

  def holiday_today
    holiday_on(Time.zone.now.in_time_zone(timezone).to_date)
  end

  def effective_out_of_office_message
    holiday_today&.message.presence || out_of_office_message
  end

  def working_now?
    !out_of_office?
  end

  def weekly_schedule
    working_hours.sort_by(&:day_of_week).map do |wh|
      {
        'day_of_week' => wh.day_of_week,
        'closed_all_day' => wh.closed_all_day,
        'open_hour' => wh.open_hour,
        'open_minutes' => wh.open_minutes,
        'close_hour' => wh.close_hour,
        'close_minutes' => wh.close_minutes,
        'open_all_day' => wh.open_all_day
      }
    end
  end

  # accepts an array of hashes similiar to the format of weekly_schedule
  #  [
  #    { "day_of_week"=>1,
  #      "closed_all_day"=>false,
  #      "open_hour"=>9,
  #      "open_minutes"=>0,
  #      "close_hour"=>17,
  #      "close_minutes"=>0,
  #      "open_all_day=>false" },...]
  def update_working_hours(params)
    ActiveRecord::Base.transaction do
      params.each do |working_hour|
        working_hours.find_by(day_of_week: working_hour['day_of_week']).update(working_hour.slice(*OFFISABLE_ATTRS))
      end
    end
  end

  def holiday_schedule
    inbox_holidays.sort_by { |holiday| [holiday.month, holiday.day, holiday.year || 0] }.map do |holiday|
      {
        'id' => holiday.id,
        'name' => holiday.name,
        'message' => holiday.message,
        'day' => holiday.day,
        'month' => holiday.month,
        'year' => holiday.year
      }
    end
  end

  # accepts an array of hashes similar to the format of holiday_schedule;
  # entries without an id are created, missing entries are removed
  def update_holidays(params)
    ActiveRecord::Base.transaction do
      kept_ids = params.map do |holiday|
        record = holiday['id'].present? ? inbox_holidays.find(holiday['id']) : inbox_holidays.new
        record.update!(holiday.slice(*HOLIDAY_ATTRS))
        record.id
      end
      inbox_holidays.where.not(id: kept_ids).destroy_all
    end
  end

  private

  def create_default_working_hours
    DEFAULT_WORKING_HOURS.each { |attributes| working_hours.create!(attributes) }
  end
end
