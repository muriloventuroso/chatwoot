require 'rails_helper'

RSpec.describe ProjectTask do
  let(:project) { create(:project) }
  let(:todo_column) { project.columns.find_by!(category: :todo) }
  let(:in_progress_column) { project.columns.find_by!(category: :in_progress) }
  let(:done_column) { project.columns.find_by!(category: :done) }

  it 'sets account from project' do
    task = create(:project_task, project: project, account: nil)
    expect(task.account).to eq(project.account)
  end

  it 'takes its status from the category of its column' do
    review = create(:project_column, project: project, category: :in_progress)
    task = create(:project_task, project: project, column: review)
    expect(task.status).to eq('in_progress')
  end

  it 'sets completed_at when moved to a done column' do
    task = create(:project_task, project: project)
    task.update!(column: done_column)
    expect(task.status).to eq('done')
    expect(task.completed_at).to be_present
  end

  it 'clears completed_at when moved out of a done column' do
    task = create(:project_task, project: project, status: :done)
    expect(task.completed_at).to be_present
    task.update!(column: in_progress_column)
    expect(task.completed_at).to be_nil
  end

  it 'requires a column for a root task' do
    task = build(:project_task, project: project)
    task.column = nil
    expect(task).not_to be_valid
    expect(task.errors[:column]).to be_present
  end

  it 'does not allow a column from another project' do
    other_column = create(:project).columns.first
    task = build(:project_task, project: project, column: other_column)
    expect(task).not_to be_valid
    expect(task.errors[:column]).to be_present
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
    it 'allows a subtask of a root task without a column' do
      parent = create(:project_task, project: project)
      subtask = build(:project_task, project: project, parent_task: parent)
      expect(subtask).to be_valid
      expect(subtask.column).to be_nil
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
    it 'changes column and reorders the source and destination columns' do
      first = create(:project_task, project: project, status: :todo)
      second = create(:project_task, project: project, status: :todo)
      done_task = create(:project_task, project: project, status: :done)

      first.move!(project_column_id: done_column.id, position: 1.5)

      expect(first.reload.status).to eq('done')
      expect(first.completed_at).to be_present
      expect(done_task.reload.position).to eq(1.0)
      expect(first.position).to eq(2.0)
      expect(second.reload.position).to eq(1.0)
    end

    it 'sets the status of a subtask' do
      parent = create(:project_task, project: project)
      subtask = create(:project_task, project: project, parent_task: parent)

      subtask.move!(status: 'done', position: subtask.position)

      expect(subtask.reload.status).to eq('done')
      expect(subtask.completed_at).to be_present
    end
  end
end
