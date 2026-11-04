FactoryBot.define do
  factory :project_task do
    sequence(:title) { |n| "Task #{n}" }
    description { 'Task description' }
    status { :todo }
    priority { :medium }
    project
    account { project.account }
    creator { association :user, account: account }

    trait :subtask do
      parent_task { association :project_task, project: project }
    end
  end
end
