class AddPreferredLanguageToUser < ActiveRecord::Migration
  def change
    add_column :users, :preferred_language, :string
  end
end
