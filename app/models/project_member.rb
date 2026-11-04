# == Schema Information
#
# Table name: project_members
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_project_members_on_project_id              (project_id)
#  index_project_members_on_project_id_and_user_id  (project_id,user_id) UNIQUE
#  index_project_members_on_user_id                 (user_id)
#
class ProjectMember < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :user_id, uniqueness: { scope: :project_id }
  validate :user_belongs_to_account

  private

  def user_belongs_to_account
    return if project.blank? || user.blank?
    return if user.account_users.exists?(account_id: project.account_id)

    errors.add(:user, 'must belong to the account')
  end
end
