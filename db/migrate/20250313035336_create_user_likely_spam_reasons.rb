class CreateUserLikelySpamReasons < ActiveRecord::Migration[8.0]
  def change
    create_table :user_likely_spam_reasons do |t|
      t.references :user, foreign_key: true
      t.integer :reason

      t.timestamps
    end
  end
end
