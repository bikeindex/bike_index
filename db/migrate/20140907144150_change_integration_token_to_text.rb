class ChangeIntegrationTokenToText < ActiveRecord::Migration
  def up
    change_column :integrations, :access_token, :text
  end

  def down
    change_column :integrations, :access_token, :string
  end
end
