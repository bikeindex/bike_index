class AddUserUpdatedAtToBikes < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :user_updated_at, :datetime
  end
end
