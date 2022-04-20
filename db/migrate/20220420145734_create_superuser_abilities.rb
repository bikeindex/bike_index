class CreateSuperuserAbilities < ActiveRecord::Migration[6.1]
  def change
    create_table :superuser_abilities do |t|
      t.references :user, index: true
      t.integer :kind, default: 0
      t.string :controller_name
      t.string :action_name
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
