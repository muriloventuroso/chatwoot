# == Schema Information
#
# Table name: projects
#
#  id            :bigint           not null, primary key
#  color         :string
#  description   :text
#  end_date      :date
#  name          :string           not null
#  start_date    :date
#  status        :integer          default("active"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  created_by_id :bigint
#
# Indexes
#
#  index_projects_on_account_id     (account_id)
#  index_projects_on_created_by_id  (created_by_id)
#
class Project < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :project_members, dependent: :destroy
  has_many :members, through: :project_members, source: :user
  has_many :tasks, class_name: 'ProjectTask', dependent: :destroy
  # Read-only subset of `tasks`, which already destroys them.
  has_many :root_tasks, -> { where(parent_task_id: nil) }, class_name: 'ProjectTask', inverse_of: :project, dependent: nil

  enum :status, { active: 0, completed: 1, archived: 2 }, validate: true

  validates :name, presence: true, length: { maximum: 255 }
  validate :end_date_not_before_start_date

  scope :ordered, -> { order(created_at: :desc) }

  # Counted in memory so the `root_tasks` preload of the index is reused.
  def progress
    return 0 if tasks_count.zero?

    (completed_tasks_count * 100.0 / tasks_count).round
  end

  def tasks_count
    root_tasks.size
  end

  def completed_tasks_count
    root_tasks.count(&:done?)
  end

  private

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, 'must be on or after the start date')
  end
end
