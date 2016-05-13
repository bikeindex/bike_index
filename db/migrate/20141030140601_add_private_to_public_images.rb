class AddPrivateToPublicImages < ActiveRecord::Migration
  def change
    add_column :publicImages, :is_private, :boolean, default: false, null: false
  end
end
