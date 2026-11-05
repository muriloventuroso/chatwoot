require 'rails_helper'

RSpec.describe 'Project Columns API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:project) { create(:project, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/projects/#{project.id}/columns" }

  describe 'GET /api/v1/accounts/{account.id}/projects/{project_id}/columns' do
    it 'returns the columns in order' do
      get base_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('category')).to eq(%w[todo in_progress done])
    end

    it 'returns 404 for a project of another account' do
      other_project = create(:project)

      get "/api/v1/accounts/#{account.id}/projects/#{other_project.id}/columns",
          headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/projects/{project_id}/columns' do
    it 'appends a column' do
      post base_url, params: { project_column: { name: 'Review', category: 'in_progress' } },
                     headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Review')
      expect(project.columns.last.name).to eq('Review')
    end

    it 'returns unprocessable entity for an unknown category' do
      post base_url, params: { project_column: { name: 'Review', category: 'blocked' } },
                     headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/projects/{project_id}/columns/{id}' do
    it 'renames and reorders a column' do
      column = project.columns.last

      patch "#{base_url}/#{column.id}", params: { project_column: { name: 'Shipped', position: 0.5 } },
                                        headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(project.columns.reload.first).to eq(column)
      expect(column.reload.name).to eq('Shipped')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/projects/{project_id}/columns/{id}' do
    it 'deletes an empty column' do
      column = project.columns.first

      delete "#{base_url}/#{column.id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(ProjectColumn).not_to exist(column.id)
    end

    it 'does not delete a column with tasks' do
      task = create(:project_task, project: project)

      delete "#{base_url}/#{task.project_column_id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ProjectColumn).to exist(task.project_column_id)
    end

    it 'does not delete the last column' do
      project.columns.first(2).each(&:destroy!)
      column = project.columns.reload.first

      delete "#{base_url}/#{column.id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ProjectColumn).to exist(column.id)
    end
  end
end
