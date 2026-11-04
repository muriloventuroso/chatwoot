require 'rails_helper'

RSpec.describe 'Projects API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:project) { create(:project, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/projects' do
    it 'returns unauthorized for unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/projects"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns projects of the account' do
      get "/api/v1/accounts/#{account.id}/projects", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to contain_exactly(project.id)
    end

    it 'does not return projects from another account' do
      other_project = create(:project)
      get "/api/v1/accounts/#{account.id}/projects", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body.pluck('id')).not_to include(other_project.id)
    end

    it 'returns unprocessable entity for an unknown status' do
      get "/api/v1/accounts/#{account.id}/projects",
          params: { status: 'blocked' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/projects' do
    it 'creates a project and adds the creator as member' do
      post "/api/v1/accounts/#{account.id}/projects",
           params: { project: { name: 'New Project' } },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('New Project')
      expect(Project.last.members).to contain_exactly(agent)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/projects/{id}' do
    it 'returns 404 for a project from another account' do
      other_project = create(:project)

      get "/api/v1/accounts/#{account.id}/projects/#{other_project.id}",
          headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/projects/{id}' do
    it 'updates the project' do
      patch "/api/v1/accounts/#{account.id}/projects/#{project.id}",
            params: { project: { name: 'Renamed', status: 'completed' } },
            headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Renamed')
      expect(project.reload.status).to eq('completed')
    end
  end

  describe 'project members' do
    it 'adds and lists members' do
      other_agent = create(:user, account: account, role: :agent)

      post "/api/v1/accounts/#{account.id}/projects/#{project.id}/members",
           params: { user_ids: [other_agent.id] },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('user_id')).to include(other_agent.id)
    end

    it 'removes a member' do
      membership = create(:project_member, project: project, user: agent)

      delete "/api/v1/accounts/#{account.id}/projects/#{project.id}/members/#{membership.id}",
             headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(project.members).not_to include(agent)
    end

    it 'returns unprocessable entity for a user from another account' do
      other_user = create(:user)

      post "/api/v1/accounts/#{account.id}/projects/#{project.id}/members",
           params: { user_ids: [other_user.id] },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(project.members).not_to include(other_user)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/projects/{id}' do
    it 'destroys the project with its tasks' do
      create(:project_task, project: project)

      delete "/api/v1/accounts/#{account.id}/projects/#{project.id}",
             headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(Project.count).to eq(0)
      expect(ProjectTask.count).to eq(0)
    end
  end
end
