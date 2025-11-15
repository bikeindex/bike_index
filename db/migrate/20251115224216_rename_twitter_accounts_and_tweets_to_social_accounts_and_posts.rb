class RenameTwitterAccountsAndTweetsToSocialAccountsAndPosts < ActiveRecord::Migration[8.0]
  def change
    # Rename tables
    rename_table :twitter_accounts, :social_accounts
    rename_table :tweets, :social_posts

    # Rename columns in social_posts (formerly tweets)
    rename_column :social_posts, :twitter_account_id, :social_account_id
    rename_column :social_posts, :original_tweet_id, :original_post_id
    rename_column :social_posts, :twitter_id, :platform_id
    rename_column :social_posts, :twitter_response, :platform_response

    # Rename columns in social_accounts (formerly twitter_accounts)
    rename_column :social_accounts, :twitter_account_info, :account_info
  end
end
