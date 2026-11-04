require 'rails_helper'

RSpec.describe Project do
  let(:project) { create(:project) }

  it 'validates presence of name' do
    project.name = nil
    expect(project).not_to be_valid
  end

  it 'validates end_date is not before start_date' do
    project.start_date = Date.current
    project.end_date = Date.yesterday
    expect(project).not_to be_valid
    expect(project.errors[:end_date]).to be_present
  end

  it 'stays editable after its creator is deleted' do
    project.created_by.destroy!

    expect(project.reload.created_by_id).to be_nil
    expect(project.update(name: 'Renamed')).to be(true)
  end

  describe '#progress' do
    it 'returns 0 when there are no tasks' do
      expect(project.progress).to eq(0)
    end

    it 'returns percentage of completed root tasks' do
      create(:project_task, project: project, status: :done)
      create(:project_task, project: project, status: :todo)
      expect(project.progress).to eq(50)
    end

    it 'ignores subtasks' do
      parent = create(:project_task, project: project, status: :done)
      create(:project_task, project: project, parent_task: parent, status: :todo)
      expect(project.progress).to eq(100)
    end
  end
end
