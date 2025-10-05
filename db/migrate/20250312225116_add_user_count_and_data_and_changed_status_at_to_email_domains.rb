class AddUserCountAndDataAndChangedStatusAtToEmailDomains < ActiveRecord::Migration[8.0]
  def change
    add_column :email_domains, :user_count, :integer
    add_column :email_domains, :status_changed_at, :datetime
    add_column :email_domains, :data, :jsonb
  end
end
