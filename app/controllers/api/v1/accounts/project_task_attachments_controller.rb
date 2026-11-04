class Api::V1::Accounts::ProjectTaskAttachmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_task
  before_action -> { check_authorization(ProjectTask) }

  def create
    @project_task.attachments.attach(params.require(:file))
    @project_task.reload
  end

  def destroy
    attachment = @project_task.attachments.find(params[:id])
    attachment.purge
    head :ok
  end

  private

  def fetch_task
    @project_task = Current.account.project_tasks.find(params[:project_task_id])
  end
end
