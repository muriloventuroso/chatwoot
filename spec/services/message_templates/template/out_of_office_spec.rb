require 'rails_helper'

describe MessageTemplates::Template::OutOfOffice do
  context 'when this hook is called' do
    let(:conversation) { create(:conversation) }

    it 'creates the out of office messages' do
      described_class.new(conversation: conversation).perform
      expect(conversation.messages.template.count).to eq(1)
      expect(conversation.messages.template.first.content).to eq(conversation.inbox.out_of_office_message)
    end

    it 'creates the out of office messages with template variable' do
      conversation.inbox.update!(out_of_office_message: 'Hey, {{contact.name}} we are unavailable at the moment.')
      described_class.new(conversation: conversation).perform
      expect(conversation.messages.count).to eq(1)
      expect(conversation.messages.last.content).to eq("Hey, #{conversation.contact.name} we are unavailable at the moment.")
    end

    context 'when today is a holiday' do
      let(:today) { Time.zone.now.in_time_zone(conversation.inbox.timezone).to_date }

      before do
        conversation.inbox.update!(working_hours_enabled: true, out_of_office_message: 'We are out of office')
      end

      it 'sends the holiday message instead of the default one' do
        conversation.inbox.inbox_holidays.create!(day: today.day, month: today.month, year: today.year, message: 'Holiday message')

        described_class.new(conversation: conversation).perform

        expect(conversation.messages.template.first.content).to eq('Holiday message')
      end

      it 'sends the default message when the holiday has no message of its own' do
        conversation.inbox.inbox_holidays.create!(day: today.day, month: today.month, year: today.year)

        described_class.new(conversation: conversation).perform

        expect(conversation.messages.template.first.content).to eq('We are out of office')
      end
    end

    it 'creates the out of office messages with more than one variable strings' do
      conversation.inbox.update!(out_of_office_message:
        'Hey, {{contact.name}} we are unavailable at the moment. - from {{account.name}}')
      described_class.new(conversation: conversation).perform
      expect(conversation.messages.count).to eq(1)
      expect(conversation.messages.last.content).to eq(
        "Hey, #{conversation.contact.name} we are unavailable at the moment. - from #{conversation.account.name}"
      )
    end
  end
end
