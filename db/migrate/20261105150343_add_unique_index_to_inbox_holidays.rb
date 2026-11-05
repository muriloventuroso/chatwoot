class AddUniqueIndexToInboxHolidays < ActiveRecord::Migration[7.2]
  def change
    add_index :inbox_holidays, %i[inbox_id month year day], unique: true, nulls_not_distinct: true
  end
end
