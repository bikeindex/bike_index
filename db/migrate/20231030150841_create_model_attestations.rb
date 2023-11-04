class CreateModelAttestations < ActiveRecord::Migration[6.1]
  def change
    create_table :model_attestations do |t|
      t.references :model_tracker, index: true
      t.integer :kind
      t.references :user, index: true
      t.references :organization, index: true

      t.text :url
      t.text :info

      t.timestamps
    end
  end
end
