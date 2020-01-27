class AddPreferredLanguageToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :preferred_language, :string
  end
end
