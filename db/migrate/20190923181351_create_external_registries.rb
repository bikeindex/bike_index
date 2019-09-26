class CreateExternalRegistries < ActiveRecord::Migration
  def change
    create_table :external_registries do |t|
      t.string :name, null: false
      t.string :client_class, null: false
      t.string :url
      t.belongs_to :country, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
