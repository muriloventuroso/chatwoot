FactoryBot.define do
  factory :project_column do
    sequence(:name) { |n| "Column #{n}" }
    category { :in_progress }
    project
  end
end
