# Rename User.password_reset_token because has_secure_password update in Rails 8
# Now, it generates password_reset_token on initialize
# See https://github.com/rails/rails/pull/52483
# So switch to an unused attribute
class RenameUserPasswordResetToken < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :password_reset_token, :token_for_password_reset
  end
end
