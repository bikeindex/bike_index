class RemoveBikeTokens < ActiveRecord::Migration
  def up
    remove_column :organizations, :default_bike_token_count
    drop_table :bike_tokens
    drop_table :bike_token_invitations
    remove_column :bikes, :created_with_token
    remove_column :b_params, :bike_token_id
    remove_column :users, :can_invite
  end
end
