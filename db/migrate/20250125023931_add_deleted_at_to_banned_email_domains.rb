class AddDeletedAtToBannedEmailDomains < ActiveRecord::Migration[7.1]
  def change
    add_column :banned_email_domains, :deleted_at, :datetime
  end
end
