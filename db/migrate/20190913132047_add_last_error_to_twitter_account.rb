class AddLastErrorToTwitterAccount < ActiveRecord::Migration[4.2]
  def change
    change_table :twitter_accounts do |t|
      t.string :last_error
    end
  end
end
