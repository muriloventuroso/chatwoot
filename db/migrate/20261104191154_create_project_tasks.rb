class CreateProjectTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :project_tasks do |t|
      t.references :account, null: false, index: true
      t.references :project, null: false, index: true
      t.references :parent_task, index: true
      t.string :title, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.integer :priority, null: false, default: 1
      t.references :assignee, index: true
      t.references :creator, index: true
      t.date :due_date
      t.float :position, null: false, default: 0.0
      t.datetime :completed_at
      t.integer :comments_count, null: false, default: 0

      t.timestamps
    end

    add_index :project_tasks, [:project_id, :parent_task_id, :status, :position], name: 'index_project_tasks_on_project_parent_status_position'
  end
end
