require 'rails_helper'

RSpec.describe 'Project Tasks API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:project) { create(:project, account: account) }
  let!(:task) { create(:project_task, project: project, title: 'First task') }

  describe 'GET /api/v1/accounts/{account.id}/projects/{project_id}/tasks' do
    it 'returns root tasks of the project' do
      create(:project_task, project: project, parent_task: task, title: 'Subtask')
      create(:project_task_comment, project_task: task)

      get "/api/v1/accounts/#{account.id}/projects/#{project.id}/tasks",
          headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('title')).to contain_exactly('First task')
      expect(response.parsed_body.first['subtasks_count']).to eq(1)
      expect(response.parsed_body.first['comments_count']).to eq(1)
    end

    it 'filters by status' do
      create(:project_task, project: project, status: :done, title: 'Done task')

      get "/api/v1/accounts/#{account.id}/projects/#{project.id}/tasks",
          params: { status: 'done' }, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body.pluck('title')).to contain_exactly('Done task')
    end

    it 'returns unprocessable entity for an unknown status' do
      get "/api/v1/accounts/#{account.id}/projects/#{project.id}/tasks",
          params: { status: 'blocked' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/projects/{project_id}/tasks' do
    it 'creates a task' do
      post "/api/v1/accounts/#{account.id}/projects/#{project.id}/tasks",
           params: { project_task: { title: 'New task', priority: 'high' } },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['title']).to eq('New task')
      expect(response.parsed_body['priority']).to eq('high')
    end

    it 'creates a subtask' do
      post "/api/v1/accounts/#{account.id}/projects/#{project.id}/tasks",
           params: { project_task: { title: 'Subtask', parent_task_id: task.id } },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(task.subtasks.pluck(:title)).to contain_exactly('Subtask')
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/project_tasks/{id}/move' do
    it 'moves the task to another column' do
      post "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}/move",
           params: { project_task: { status: 'done', position: 1 } },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(task.reload.status).to eq('done')
      expect(task.completed_at).to be_present
    end

    it 'returns unprocessable entity for an unknown status' do
      post "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}/move",
           params: { project_task: { status: 'blocked', position: 1 } },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(task.reload.status).to eq('todo')
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/project_tasks/{id}' do
    it 'does not re-parent an existing task' do
      patch "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}",
            params: { project_task: { title: 'Renamed', parent_task_id: task.id } },
            headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(task.reload.title).to eq('Renamed')
      expect(task.parent_task_id).to be_nil
    end

    it 'does not change status or position' do
      task.update!(position: 3)

      patch "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}",
            params: { project_task: { title: 'Renamed', status: 'done', position: 99 } },
            headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      task.reload
      expect(task.title).to eq('Renamed')
      expect(task.status).to eq('todo')
      expect(task.position).to eq(3)
    end
  end

  describe 'comments and attachments' do
    it 'creates and lists comments' do
      post "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}/comments",
           params: { comment: { content: 'Hello' } },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['content']).to eq('Hello')
      expect(response.parsed_body['author']['id']).to eq(agent.id)

      get "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}/comments",
          headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('content')).to contain_exactly('Hello')
    end

    it 'allows the author to delete a comment' do
      comment = create(:project_task_comment, project_task: task, author: agent)

      delete "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}/comments/#{comment.id}",
             headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(ProjectTaskComment).not_to exist(comment.id)
    end

    it 'does not allow deleting another user comment as agent' do
      other_agent = create(:user, account: account, role: :agent)
      comment = create(:project_task_comment, project_task: task, author: other_agent)

      delete "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}/comments/#{comment.id}",
             headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows an administrator to delete another user comment' do
      admin = create(:user, account: account, role: :administrator)
      other_agent = create(:user, account: account, role: :agent)
      comment = create(:project_task_comment, project_task: task, author: other_agent)

      delete "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}/comments/#{comment.id}",
             headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(ProjectTaskComment).not_to exist(comment.id)
    end

    it 'attaches a file to the task' do
      file = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')

      post "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}/attachments",
           params: { file: file },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(task.attachments.count).to eq(1)
      expect(response.parsed_body['attachments'].first['filename']).to eq('avatar.png')
    end

    it 'removes an attachment from the task' do
      task.attachments.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      attachment = task.attachments.first

      delete "/api/v1/accounts/#{account.id}/project_tasks/#{task.id}/attachments/#{attachment.id}",
             headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(task.reload.attachments).to be_empty
    end
  end

  describe 'cross-account access' do
    it 'returns 404 for a task from another account' do
      other_task = create(:project_task)

      get "/api/v1/accounts/#{account.id}/project_tasks/#{other_task.id}",
          headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when commenting on a task from another account' do
      other_task = create(:project_task)

      post "/api/v1/accounts/#{account.id}/project_tasks/#{other_task.id}/comments",
           params: { comment: { content: 'Hello' } },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
      expect(other_task.comments).to be_empty
    end
  end
end
