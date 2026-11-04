class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.references :account, null: false, index: true
      t.references :created_by, index: true
      t.string :name, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.string :color
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
  end
end
