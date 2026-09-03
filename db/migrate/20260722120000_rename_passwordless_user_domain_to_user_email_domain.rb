class RenamePasswordlessUserDomainToUserEmailDomain < ActiveRecord::Migration[8.0]
  def change
    rename_column :organizations, :passwordless_user_domain, :user_email_domain
  end
end
