require 'rails_helper'

RSpec.describe ProjectColumn do
  let(:project) { create(:project) }

  it 'appends a new column after the existing ones' do
    column = create(:project_column, project: project)
    expect(project.columns.last).to eq(column)
  end

  it 'updates the status of its tasks when the category changes' do
    column = create(:project_column, project: project, category: :in_progress)
    task = create(:project_task, project: project, column: column)

    column.update!(category: :done)

    expect(task.reload.status).to eq('done')
    expect(task.completed_at).to be_present
    expect(project.reload.progress).to eq(100)
  end

  it 'is not destroyed while it has tasks' do
    column = create(:project_column, project: project)
    create(:project_task, project: project, column: column)

    expect(column.destroy).to be(false)
    expect(described_class).to exist(column.id)
  end

  it 'is destroyed with its project, tasks included' do
    create(:project_task, project: project, status: :done)

    expect { project.destroy! }.to change(described_class, :count).by(-3)
  end
end
