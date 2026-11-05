class Api::V1::Accounts::ProjectColumnsController < Api::V1::Accounts::BaseController
  before_action :fetch_project
  before_action -> { check_authorization(Project) }
  before_action :fetch_column, only: [:update, :destroy]

  def index
    @project_columns = @project.columns
  end

  def create
    @project_column = @project.columns.create!(column_params)
    render :show
  end

  def update
    @project_column.update!(column_params)
    render :show
  end

  def destroy
    # Root tasks always need a column, and a new task needs one to land in.
    return render_could_not_create_error('A project needs at least one column') if @project.columns.one?
    return render_could_not_create_error('Move the tasks out of the column before deleting it') unless @project_column.destroy

    head :ok
  end

  private

  def fetch_project
    @project = Current.account.projects.find(params[:project_id])
  end

  def fetch_column
    @project_column = @project.columns.find(params[:id])
  end

  def column_params
    params.require(:project_column).permit(:name, :category, :position)
  end
end
