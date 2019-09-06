class AddColumnsToTweets < ActiveRecord::Migration
  def change
    change_table :tweets do |t|
      t.string :twitter_account_id
      t.string :stolen_record_id
      t.integer :original_tweet_id
    end
  end
end
