class RemoveGeocoderColumnsFromImpoundRecords < ActiveRecord::Migration[8.1]
  def change
    change_table :impound_records, bulk: true do |t|
      t.remove :street, type: :text
      t.remove :city, type: :text
      t.remove :neighborhood, type: :text
      t.remove :zipcode, type: :text
      t.remove :latitude, type: :float
      t.remove :longitude, type: :float
      t.remove :state_id, type: :bigint, index: true
      t.remove :country_id, type: :bigint, index: true
    end
  end
end
