class AddOwnershipsCounterCacheToOauthApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :oauth_applications, :ownerships_count, :integer, default: 0, null: false
  end
end
