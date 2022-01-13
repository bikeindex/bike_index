class AddUserUpdatedAtToBikes < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :updated_by_user_at, :datetime
  end
end
