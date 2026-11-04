class ProjectTaskPolicy < ApplicationPolicy
  def index?
    account_user.present?
  end

  def show?
    account_user.present?
  end

  def create?
    account_user.present?
  end

  def update?
    account_user.present?
  end

  def destroy?
    account_user.present?
  end

  def move?
    account_user.present?
  end
end

ProjectTaskPolicy.prepend_mod_with('ProjectTaskPolicy')
