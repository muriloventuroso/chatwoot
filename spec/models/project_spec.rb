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

  describe 'default columns' do
    it 'creates a to do, an in progress and a done column in order' do
      expect(project.columns.map { |column| [column.name, column.category] }).to eq(
        [['To do', 'todo'], ['In progress', 'in_progress'], %w[Done done]]
      )
    end

    it 'names them in the current locale' do
      I18n.with_locale(:pt_BR) do
        expect(create(:project).columns.map(&:name)).to eq(['A fazer', 'Em andamento', 'Concluído'])
      end
    end
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

  describe '#overdue_tasks_count' do
    it 'counts the root tasks past their due date that are not done' do
      create(:project_task, project: project, status: :todo, due_date: Date.yesterday)
      create(:project_task, project: project, status: :done, due_date: Date.yesterday)
      create(:project_task, project: project, status: :todo, due_date: Date.current)
      parent = create(:project_task, project: project, status: :todo)
      create(:project_task, project: project, parent_task: parent, status: :todo, due_date: Date.yesterday)

      expect(project.overdue_tasks_count).to eq(1)
    end
  end
end
