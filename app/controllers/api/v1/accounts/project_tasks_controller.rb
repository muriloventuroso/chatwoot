class Api::V1::Accounts::ProjectTasksController < Api::V1::Accounts::BaseController
  before_action :fetch_project, only: [:index, :create]
  before_action :fetch_task, only: [:show, :update, :destroy, :move]
  before_action -> { check_authorization(ProjectTask) }, except: [:move]
  before_action -> { authorize(@project_task) }, only: [:move]

  def index
    if params[:status].present? && ProjectTask.statuses.keys.exclude?(params[:status])
      return render_could_not_create_error('Invalid status')
    end
    if params[:priority].present? && ProjectTask.priorities.keys.exclude?(params[:priority])
      return render_could_not_create_error('Invalid priority')
    end

    @project_tasks = @project.tasks.root.includes(:assignee, :subtasks, attachments_attachments: :blob).ordered
    @project_tasks = filter_tasks(@project_tasks)
  end

  def show; end

  def create
    @project_task = @project.tasks.new(create_task_params)
    @project_task.creator = Current.user
    @project_task.save!
    render :show
  end

  def update
    @project_task.update!(task_params)
    render :show
  end

  def destroy
    @project_task.destroy!
    head :ok
  end

  def move
    @project_task.move!(new_status: move_params[:status], new_position: move_params[:position].to_f)
    render :show
  end

  private

  def filter_tasks(tasks)
    tasks = tasks.where(status: params[:status]) if params[:status].present?
    tasks = tasks.where(priority: params[:priority]) if params[:priority].present?
    tasks = tasks.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    tasks = tasks.where(assignee_id: Current.user.id) if params[:mine] == 'true'
    tasks
  end

  def fetch_project
    @project = Current.account.projects.find(params[:project_id])
  end

  def fetch_task
    @project_task = Current.account.project_tasks.includes(:assignee, :subtasks, attachments_attachments: :blob).find(params[:id])
  end

  def task_params
    params.require(:project_task).permit(:title, :description, :priority, :assignee_id, :due_date)
  end

  # Status/position changes go through `move` so the column is reordered.
  # A task only becomes a subtask at creation; re-parenting would allow cycles and nested subtasks.
  def create_task_params
    task_params.merge(params.require(:project_task).permit(:parent_task_id, :status))
  end

  def move_params
    params.require(:project_task).permit(:status, :position)
  end
end
