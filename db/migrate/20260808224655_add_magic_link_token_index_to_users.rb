class AddMagicLinkTokenIndexToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Only the few users with an outstanding link are worth indexing
    add_index :users, :magic_link_token, where: "magic_link_token IS NOT NULL",
      name: "index_users_on_magic_link_token_outstanding", algorithm: :concurrently
  end
end
