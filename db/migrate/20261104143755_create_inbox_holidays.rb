class CreateInboxHolidays < ActiveRecord::Migration[7.1]
  def change
    create_table :inbox_holidays do |t|
      t.references :inbox, index: true
      t.references :account, index: true
      t.string :name
      t.string :message
      t.integer :day, null: false
      t.integer :month, null: false
      t.integer :year

      t.timestamps
    end
  end
end
