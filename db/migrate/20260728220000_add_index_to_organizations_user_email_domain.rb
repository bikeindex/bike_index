class AddIndexToOrganizationsUserEmailDomain < ActiveRecord::Migration[8.1]
  def change
    # Forced-SSO runs a user_email_domain lookup on every credential entry point,
    # so an unindexed column means a sequential scan on each sign in attempt
    add_index :organizations, :user_email_domain
  end
end
