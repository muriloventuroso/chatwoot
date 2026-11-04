require 'rails_helper'

shared_examples_for 'out_of_offisable' do
  let(:obj) { create(described_class.to_s.underscore, working_hours_enabled: true, out_of_office_message: 'Message') }

  it 'has after create callback' do
    expect(obj.working_hours.count).to eq(7)
  end

  it 'is working on monday 10am' do
    travel_to '26.10.2020 10:00'.to_datetime
    expect(obj.working_now?).to be true
  end

  it 'is out of office on sunday 1pm' do
    travel_to '01.11.2020 13:00'.to_datetime
    expect(obj.out_of_office?).to be true
  end

  it 'updates the office hours via a hash' do
    obj.update_working_hours([{ 'day_of_week' => 1, 'open_hour' => 10, 'open_minutes' => 0,
                                'close_hour' => 17, 'close_minutes' => 0 }])
    expect(obj.reload.weekly_schedule.find { |schedule| schedule['day_of_week'] == 1 }['open_hour']).to eq 10
  end

  context 'with holidays' do
    it 'is out of office on a specific holiday even during working hours' do
      obj.inbox_holidays.create!(day: 26, month: 10, year: 2020)
      travel_to '26.10.2020 10:00'.to_datetime
      expect(obj.out_of_office?).to be true
    end

    it 'is out of office on a recurring holiday in a later year' do
      obj.inbox_holidays.create!(day: 26, month: 10, year: nil)
      # 26.10.2021 is a Tuesday, a regular working day
      travel_to '26.10.2021 10:00'.to_datetime
      expect(obj.out_of_office?).to be true
    end

    it 'uses the holiday message over the default out of office message' do
      obj.inbox_holidays.create!(day: 26, month: 10, year: 2020, message: 'Holiday message')
      travel_to '26.10.2020 10:00'.to_datetime
      expect(obj.effective_out_of_office_message).to eq 'Holiday message'
    end

    it 'falls back to the default message when the holiday has no message' do
      obj.inbox_holidays.create!(day: 26, month: 10, year: 2020)
      travel_to '26.10.2020 10:00'.to_datetime
      expect(obj.effective_out_of_office_message).to eq 'Message'
    end

    it 'prefers a specific holiday over a recurring one on the same day' do
      obj.inbox_holidays.create!(day: 26, month: 10, year: nil, message: 'Recurring message')
      obj.inbox_holidays.create!(day: 26, month: 10, year: 2020, message: 'Specific message')
      travel_to '26.10.2020 10:00'.to_datetime
      expect(obj.effective_out_of_office_message).to eq 'Specific message'
    end

    it 'considers the holiday in the inbox timezone' do
      obj.update!(timezone: 'Australia/Sydney')
      obj.inbox_holidays.create!(day: 27, month: 10, year: 2020)
      # 26.10.2020 22:00 UTC is already 27.10 in Sydney
      travel_to '26.10.2020 22:00'.to_datetime
      expect(obj.out_of_office?).to be true
    end

    it 'syncs holidays via update_holidays, removing the missing ones' do
      holiday = obj.inbox_holidays.create!(day: 25, month: 12, year: nil, name: 'Christmas')
      obj.update_holidays([
                            { 'id' => holiday.id, 'day' => 25, 'month' => 12, 'year' => nil, 'name' => 'Christmas Day' },
                            { 'day' => 1, 'month' => 1, 'year' => nil, 'name' => 'New Year' }
                          ])

      expect(obj.reload.holiday_schedule).to contain_exactly(
        hash_including('name' => 'Christmas Day', 'day' => 25, 'month' => 12, 'year' => nil),
        hash_including('name' => 'New Year', 'day' => 1, 'month' => 1, 'year' => nil)
      )

      obj.update_holidays([])
      expect(obj.reload.inbox_holidays).to be_empty
    end
  end
end
