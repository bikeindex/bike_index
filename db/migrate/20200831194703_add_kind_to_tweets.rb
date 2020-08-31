class AddKindToTweets < ActiveRecord::Migration[5.2]
  def change
    add_column :tweets, :kind, :integer
  end
end
