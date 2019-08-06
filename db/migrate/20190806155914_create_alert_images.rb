class CreateAlertImages < ActiveRecord::Migration
  def change
    create_table :alert_images do |t|
      t.belongs_to :stolen_record, null: false, index: true, foreign_key: true
      t.string :image

      t.timestamps null: false
    end
  end
end
