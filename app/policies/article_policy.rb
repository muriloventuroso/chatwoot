class ArticlePolicy < ApplicationPolicy
  def index?
    @account.users.include?(@user)
  end

  def update?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def edit?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def reorder?
    @account_user.administrator?
  end

  # Whoever can edit the article can ask for tag suggestions (Enterprise widens update? for custom roles).
  def generate_tags?
    update?
  end
end

ArticlePolicy.prepend_mod_with('ArticlePolicy')
