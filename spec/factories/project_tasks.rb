FactoryBot.define do
  factory :project_task do
    sequence(:title) { |n| "Task #{n}" }
    description { 'Task description' }
    status { :todo }
    priority { :medium }
    project
    account { project.account }
    creator { association :user, account: account }

    # Root tasks land in the project's default column for their status.
    after(:build) do |task|
      task.column ||= task.project.columns.find_by(category: task.status) if task.parent_task.nil?
    end

    trait :subtask do
      parent_task { association :project_task, project: project }
    end
  end
end
