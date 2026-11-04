class Api::V1::Accounts::ProjectsController < Api::V1::Accounts::BaseController
  before_action :fetch_project, only: [:show, :update, :destroy]
  before_action -> { check_authorization(Project) }

  def index
    if params[:status].present? && Project.statuses.keys.exclude?(params[:status])
      return render_could_not_create_error('Invalid status')
    end

    @projects = Current.account.projects.includes(:members, :root_tasks).ordered
    @projects = @projects.where(status: params[:status]) if params[:status].present?
    return unless params[:mine] == 'true'

    @projects = @projects.joins(:project_members).where(project_members: { user_id: Current.user.id })
  end

  def show; end

  def create
    @project = Current.account.projects.new(project_params)
    @project.created_by = Current.user
    Project.transaction do
      @project.save!
      @project.project_members.find_or_create_by!(user: Current.user)
    end
    @project.reload
    render :create
  end

  def update
    @project.update!(project_params)
  end

  def destroy
    @project.destroy!
    head :ok
  end

  private

  def fetch_project
    @project = Current.account.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description, :status, :color, :start_date, :end_date)
  end
end
