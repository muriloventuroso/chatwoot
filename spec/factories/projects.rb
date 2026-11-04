FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "Project #{n}" }
    description { 'Project description' }
    status { :active }
    account
    created_by { association :user, account: account }
  end
end
