class AddLastErrorToTwitterAccount < ActiveRecord::Migration
  def change
    change_table :twitter_accounts do |t|
      t.string :last_error
    end
  end
end
