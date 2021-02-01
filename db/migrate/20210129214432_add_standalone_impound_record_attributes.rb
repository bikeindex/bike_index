class AddStandaloneImpoundRecordAttributes < ActiveRecord::Migration[5.2]
  def change
    change_table :impound_records do |t|
      t.datetime :impounded_at

      # Location fields
      t.float :latitude
      t.float :longitude
      t.text :street
      t.text :zipcode
      t.text :city
      t.text :neighborhood
      t.references :country, index: true
      t.references :state, index: true
    end

    add_reference :bikes, :current_impound_record
  end
end
