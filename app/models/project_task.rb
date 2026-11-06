# == Schema Information
#
# Table name: project_tasks
#
#  id                :bigint           not null, primary key
#  comments_count    :integer          default(0), not null
#  completed_at      :datetime
#  description       :text
#  due_date          :date
#  position          :float            default(0.0), not null
#  priority          :integer          default("medium"), not null
#  status            :integer          default("todo"), not null
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  assignee_id       :bigint
#  creator_id        :bigint
#  parent_task_id    :bigint
#  project_column_id :bigint
#  project_id        :bigint           not null
#
# Indexes
#
#  index_project_tasks_on_account_id                      (account_id)
#  index_project_tasks_on_assignee_id                     (assignee_id)
#  index_project_tasks_on_creator_id                      (creator_id)
#  index_project_tasks_on_parent_task_id                  (parent_task_id)
#  index_project_tasks_on_project_column_id               (project_column_id)
#  index_project_tasks_on_project_id                      (project_id)
#  index_project_tasks_on_project_parent_status_position  (project_id,parent_task_id,status,position)
#
class ProjectTask < ApplicationRecord
  belongs_to :account
  belongs_to :project
  belongs_to :parent_task, class_name: 'ProjectTask', optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :creator, class_name: 'User', optional: true
  # Root tasks sit in a column; subtasks only carry a status.
  belongs_to :column, class_name: 'ProjectColumn', foreign_key: :project_column_id, optional: true, inverse_of: :tasks

  has_many :subtasks, class_name: 'ProjectTask', foreign_key: :parent_task_id, inverse_of: :parent_task, dependent: :destroy
  has_many :comments, class_name: 'ProjectTaskComment', dependent: :destroy

  has_many_attached :attachments

  enum :status, { todo: 0, in_progress: 1, done: 2 }, validate: true
  enum :priority, { low: 0, medium: 1, high: 2 }, validate: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :column, presence: true, if: -> { parent_task_id.nil? }
  validate :column_belongs_to_same_project
  validate :parent_task_is_root
  validate :parent_task_belongs_to_same_project
  # Only on change, so removing a member does not lock their existing tasks.
  validate :assignee_is_project_member, if: :assignee_id_changed?

  before_validation :set_account_from_project
  before_validation :sync_status_from_column
  before_save :sync_completed_at
  before_create :set_position, if: -> { position.to_f.zero? }

  scope :root, -> { where(parent_task_id: nil) }
  scope :ordered, -> { order(:position, :created_at) }

  def subtasks_count
    subtasks.size
  end

  def completed_subtasks_count
    subtasks.count(&:done?)
  end

  # Moves a root task to a column, or sets a subtask's status, at the given
  # position, reordering only the tasks of the affected columns.
  def move!(attributes)
    transaction do
      source_column_id = project_column_id
      update!(attributes)

      reorder_column(source_column_id) if source_column_id != project_column_id
      reorder_column(project_column_id)
    end
    reload
  end

  private

  def reorder_column(column_id)
    tasks = self.class.where(project_id: project_id, parent_task_id: parent_task_id, project_column_id: column_id).ordered.lock
    tasks.each_with_index do |task, index|
      new_position = (index + 1).to_f
      next if task.position == new_position

      task.update_columns(position: new_position, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def set_account_from_project
    self.account_id = project.account_id if project.present?
  end

  def set_position
    last_position = self.class.where(project_id: project_id, parent_task_id: parent_task_id, project_column_id: project_column_id).maximum(:position)
    self.position = (last_position || 0).to_f + 1
  end

  def sync_status_from_column
    self.status = column.category if column.present?
  end

  def sync_completed_at
    if status_changed?
      self.completed_at = done? ? Time.current : nil
    elsif done? && completed_at.blank?
      self.completed_at = Time.current
    end
  end

  def parent_task_is_root
    return if parent_task.blank?
    return if parent_task.parent_task_id.blank?

    errors.add(:parent_task, 'cannot be a subtask')
  end

  def parent_task_belongs_to_same_project
    return if parent_task.blank? || project_id.blank?
    return if parent_task.project_id == project_id

    errors.add(:parent_task, 'must belong to the same project')
  end

  def column_belongs_to_same_project
    return if column.blank? || column.project_id == project_id

    errors.add(:column, 'must belong to the same project')
  end

  def assignee_is_project_member
    return if assignee_id.blank? || project.blank?
    return if project.project_members.exists?(user_id: assignee_id)

    errors.add(:assignee, 'must be a member of the project')
  end
end
