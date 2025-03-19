class DropTableUserLikelySpamReasons < ActiveRecord::Migration[8.0]
  def change
    drop_table :user_likely_spam_reasons
  end
end
