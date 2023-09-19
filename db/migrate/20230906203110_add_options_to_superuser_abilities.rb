class AddOptionsToSuperuserAbilities < ActiveRecord::Migration[6.1]
  def change
    add_column :superuser_abilities, :su_options, :jsonb, default: []
  end
end
