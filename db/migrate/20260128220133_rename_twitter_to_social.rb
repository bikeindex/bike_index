class RenameTwitterToSocial < ActiveRecord::Migration[8.1]
  def change
    # Rename twitter_accounts → social_accounts
    rename_table :twitter_accounts, :social_accounts
    rename_column :social_accounts, :twitter_account_info, :account_info

    # Rename tweets → social_posts
    rename_table :tweets, :social_posts
    rename_column :social_posts, :twitter_id, :platform_id
    rename_column :social_posts, :twitter_response, :platform_response
    rename_column :social_posts, :twitter_account_id, :social_account_id
    rename_column :social_posts, :original_tweet_id, :original_post_id
  end
end
