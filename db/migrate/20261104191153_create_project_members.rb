class CreateProjectMembers < ActiveRecord::Migration[7.1]
  def change
    create_table :project_members do |t|
      t.references :project, null: false, index: true
      t.references :user, null: false, index: true

      t.timestamps
    end

    add_index :project_members, [:project_id, :user_id], unique: true
  end
end
