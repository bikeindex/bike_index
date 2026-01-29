class AddPlatformToSocialModels < ActiveRecord::Migration[8.1]
  def change
    add_column :social_accounts, :platform, :integer, default: 0, null: false
    add_column :social_posts, :platform, :integer, default: 0, null: false

    add_index :social_accounts, :platform
    add_index :social_posts, :platform
  end
end
