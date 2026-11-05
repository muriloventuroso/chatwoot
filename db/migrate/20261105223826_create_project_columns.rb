class CreateProjectColumns < ActiveRecord::Migration[7.1]
  def up
    create_table :project_columns do |t|
      t.references :project, null: false, index: true
      t.string :name, null: false
      t.integer :category, null: false, default: 0
      t.float :position, null: false, default: 0

      t.timestamps
    end
    add_reference :project_tasks, :project_column, index: true

    ProjectTask.reset_column_information
    # Existing projects get the three columns they showed before, and each root task lands in the one matching its status.
    Project.includes(:account).find_each do |project|
      I18n.with_locale(project.account.locale) { project.create_default_columns! }
      project.columns.each do |column|
        project.tasks.root.where(status: column.category).update_all(project_column_id: column.id) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  def down
    remove_reference :project_tasks, :project_column, index: true
    drop_table :project_columns
  end
end
