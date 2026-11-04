FactoryBot.define do
  factory :project_task_comment do
    content { 'A comment' }
    project_task
    author { association :user, account: project_task.account }
  end
end
