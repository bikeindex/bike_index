class CreateTweets < ActiveRecord::Migration
  def change
    create_table :tweets do |t|
      t.string :twitter_id
      t.json :twitter_response
      t.text :body_html

      t.timestamps null: false
    end
  end
end
