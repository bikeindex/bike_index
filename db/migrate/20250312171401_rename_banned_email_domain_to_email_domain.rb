class RenameBannedEmailDomainToEmailDomain < ActiveRecord::Migration[8.0]
  def change
    rename_table :banned_email_domains, :email_domains
    add_column :email_domains, :status, :integer, default: 0, null: 0
  end
end
