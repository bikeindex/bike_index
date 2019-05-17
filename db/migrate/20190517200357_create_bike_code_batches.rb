class CreateBikeCodeBatches < ActiveRecord::Migration
  def change
    create_table :bike_code_batches do |t|
      t.references :user, index: true
      t.references :organization, index: true
      t.text :notes

      t.timestamps null: false
    end

    add_reference :bike_codes, :bike_code_batch, index: true
  end
end
