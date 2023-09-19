class RemoveWebsiteFromUsers < ActiveRecord::Migration[6.1]
  def change
    remove_column :users, :website, :string
  end
end
