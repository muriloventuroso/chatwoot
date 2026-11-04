require 'rails_helper'

RSpec.describe ProjectTask do
  let(:project) { create(:project) }

  it 'sets account from project' do
    task = create(:project_task, project: project, account: nil)
    expect(task.account).to eq(project.account)
  end

  it 'sets completed_at when moved to done' do
    task = create(:project_task, project: project)
    task.update!(status: :done)
    expect(task.completed_at).to be_present
  end

  it 'clears completed_at when moved out of done' do
    task = create(:project_task, project: project, status: :done)
    expect(task.completed_at).to be_present
    task.update!(status: :in_progress)
    expect(task.completed_at).to be_nil
  end

  it 'assigns sequential positions within a column' do
    first = create(:project_task, project: project)
    second = create(:project_task, project: project)
    expect(second.position).to be > first.position
  end

  it 'does not allow an assignee from another account' do
    task = build(:project_task, project: project, assignee: create(:user))
    expect(task).not_to be_valid
    expect(task.errors[:assignee]).to be_present
  end

  describe 'subtasks' do
    it 'allows a subtask of a root task' do
      parent = create(:project_task, project: project)
      subtask = build(:project_task, project: project, parent_task: parent)
      expect(subtask).to be_valid
    end

    it 'does not allow a subtask of a subtask' do
      parent = create(:project_task, project: project)
      subtask = create(:project_task, project: project, parent_task: parent)
      nested = build(:project_task, project: project, parent_task: subtask)
      expect(nested).not_to be_valid
    end

    it 'does not allow a parent task from another project' do
      other_project = create(:project, account: project.account)
      parent = create(:project_task, project: other_project)
      subtask = build(:project_task, project: project, parent_task: parent)
      expect(subtask).not_to be_valid
    end
  end

  describe '#move!' do
    it 'changes status and reorders the destination column' do
      first = create(:project_task, project: project, status: :todo)
      second = create(:project_task, project: project, status: :todo)
      done_task = create(:project_task, project: project, status: :done)

      first.move!(new_status: 'done', new_position: 1.5)

      expect(first.reload.status).to eq('done')
      expect(first.completed_at).to be_present
      expect(done_task.reload.position).to eq(1.0)
      expect(first.position).to eq(2.0)
      expect(second.reload.position).to eq(1.0)
    end
  end
end
