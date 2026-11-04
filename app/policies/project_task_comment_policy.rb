class ProjectTaskCommentPolicy < ApplicationPolicy
  def index?
    account_user.present?
  end

  def create?
    account_user.present?
  end

  def destroy?
    return false if account_user.blank?

    account_user.administrator? || record.author_id == user.id
  end
end

ProjectTaskCommentPolicy.prepend_mod_with('ProjectTaskCommentPolicy')
