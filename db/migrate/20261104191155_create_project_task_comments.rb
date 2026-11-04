class CreateProjectTaskComments < ActiveRecord::Migration[7.1]
  def change
    create_table :project_task_comments do |t|
      t.references :project_task, null: false, index: true
      t.references :author, index: true
      t.text :content, null: false

      t.timestamps
    end
  end
end
