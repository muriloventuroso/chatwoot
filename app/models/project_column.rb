# == Schema Information
#
# Table name: project_columns
#
#  id         :bigint           not null, primary key
#  category   :integer          default("todo"), not null
#  name       :string           not null
#  position   :float            default(0.0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#
# Indexes
#
#  index_project_columns_on_project_id  (project_id)
#
class ProjectColumn < ApplicationRecord
  belongs_to :project
  has_many :tasks, class_name: 'ProjectTask', inverse_of: :column, dependent: :restrict_with_error

  # The category says what a task in this column means for progress: done columns count as completed.
  enum :category, { todo: 0, in_progress: 1, done: 2 }, validate: true

  validates :name, presence: true, length: { maximum: 255 }

  before_create :set_position, if: -> { position.to_f.zero? }
  after_update :sync_task_statuses, if: :saved_change_to_category?

  scope :ordered, -> { order(:position, :id) }

  private

  def set_position
    self.position = (project.columns.maximum(:position) || 0).to_f + 1
  end

  def sync_task_statuses
    tasks.find_each { |task| task.update!(status: category) }
  end
end
