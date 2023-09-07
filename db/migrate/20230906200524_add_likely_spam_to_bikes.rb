class AddLikelySpamToBikes < ActiveRecord::Migration[6.1]
  def change
    add_column :bikes, :likely_spam, :boolean, default: false
    add_column :users, :admin_options, :jsonb, default: nil
  end
end
