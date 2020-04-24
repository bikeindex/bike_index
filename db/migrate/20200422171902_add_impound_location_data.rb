class AddImpoundLocationData < ActiveRecord::Migration[5.2]
  def change
    add_column :locations, :not_publicly_visible, :boolean, default: false
    add_column :locations, :impound_location, :boolean, default: false
    add_column :locations, :default_impound_location, :boolean, default: false
    add_reference :impound_records, :location, index: true
    add_reference :ownerships, :impound_record, index: true
  end
end
