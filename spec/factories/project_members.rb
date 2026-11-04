FactoryBot.define do
  factory :project_member do
    project
    user { association :user, account: project.account }
  end
end
