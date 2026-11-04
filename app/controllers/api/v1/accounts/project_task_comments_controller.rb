class Api::V1::Accounts::ProjectTaskCommentsController < Api::V1::Accounts::BaseController
  before_action :fetch_task
  before_action :fetch_comment, only: [:destroy]
  before_action -> { check_authorization(ProjectTaskComment) }, only: [:index, :create]
  before_action -> { authorize(@comment) }, only: [:destroy]

  def index
    @comments = @project_task.comments.includes(:author).ordered
  end

  def create
    @comment = @project_task.comments.new(comment_params)
    @comment.author = Current.user
    @comment.save!
    render :create
  end

  def destroy
    @comment.destroy!
    head :ok
  end

  private

  def fetch_task
    @project_task = Current.account.project_tasks.find(params[:project_task_id])
  end

  def fetch_comment
    @comment = @project_task.comments.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:content)
  end
end
