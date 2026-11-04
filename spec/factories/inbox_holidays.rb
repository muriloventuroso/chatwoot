# frozen_string_literal: true

FactoryBot.define do
  factory :inbox_holiday do
    inbox
    name { 'Christmas' }
    day { 25 }
    month { 12 }
    year { nil }
  end
end
