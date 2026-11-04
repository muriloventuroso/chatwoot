class Api::V1::Accounts::ProjectMembersController < Api::V1::Accounts::BaseController
  before_action :fetch_project
  before_action -> { check_authorization(Project) }

  def index
    @project_members = @project.project_members.includes(:user).order(:created_at)
  end

  def create
    user_ids = Array(params.require(:user_ids)).map(&:to_i).uniq
    users = Current.account.users.where(id: user_ids)
    return render_could_not_create_error('Invalid User IDs') if users.size != user_ids.size

    users.each { |user| @project.project_members.find_or_create_by!(user: user) }
    @project_members = @project.project_members.includes(:user).order(:created_at)
    render :index
  end

  def destroy
    @project.project_members.find(params[:id]).destroy!
    head :ok
  end

  private

  def fetch_project
    @project = Current.account.projects.find(params[:project_id])
  end
end
