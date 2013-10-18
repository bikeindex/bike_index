class AddDefaultToCreatedWithToken < ActiveRecord::Migration
  def up
    change_column :bikes, :created_with_token, :boolean, default: false, null: false
  end
  def down
    change_column :bikes, :created_with_token, :boolean, default: false, null: false
  end
end
