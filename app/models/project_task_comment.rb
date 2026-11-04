# == Schema Information
#
# Table name: project_task_comments
#
#  id              :bigint           not null, primary key
#  content         :text             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  author_id       :bigint
#  project_task_id :bigint           not null
#
# Indexes
#
#  index_project_task_comments_on_author_id        (author_id)
#  index_project_task_comments_on_project_task_id  (project_task_id)
#
class ProjectTaskComment < ApplicationRecord
  belongs_to :project_task, counter_cache: :comments_count
  belongs_to :author, class_name: 'User', optional: true

  validates :content, presence: true

  scope :ordered, -> { order(:created_at) }
end
