class AddUserCountAndDataAndChangedStatusAtToEmailDomains < ActiveRecord::Migration[8.0]
  def change
    add_column :email_domains, :user_count, :integer
    add_column :email_domains, :changed_status_at, :datetime
    add_column :email_domains, :data, :jsonb
  end
end
