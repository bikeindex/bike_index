class AddColumnsToTweets < ActiveRecord::Migration
  def change
    change_table :tweets do |t|
      t.integer :twitter_account_id
      t.integer :stolen_record_id
      t.integer :original_tweet_id
    end

    add_index :tweets, :twitter_account_id
    add_index :tweets, :stolen_record_id
    add_index :tweets, :original_tweet_id
  end
end
