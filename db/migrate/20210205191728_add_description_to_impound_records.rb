class AddDescriptionToImpoundRecords < ActiveRecord::Migration[5.2]
  def change
    add_column :impound_records, :impounded_description, :text
  end
end
