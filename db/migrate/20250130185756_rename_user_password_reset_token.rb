# Rename User.password_reset_token because has_secure_password update in Rails 8
# See https://github.com/rails/rails/pull/52483
# And https://github.com/bikeindex/bike_index/pull/2659
class RenameUserPasswordResetToken < ActiveRecord::Migration[7.2]
  def change
    rename_column :users, :password_reset_token, :token_for_password_reset
  end
end
