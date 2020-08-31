class AddKindToTweets < ActiveRecord::Migration[5.2]
  def change
    add_column :tweets, :kind, :integer
    add_column :tweets, :twitter_response_jsonb, :jsonb
  end
end
