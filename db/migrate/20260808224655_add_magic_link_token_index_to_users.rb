class AddMagicLinkTokenIndexToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Signing in looks the token up across every user; only the few with an outstanding
    # link are worth indexing, so this stays small
    add_index :users, :magic_link_token, where: "magic_link_token IS NOT NULL",
      name: "index_users_on_magic_link_token_outstanding", algorithm: :concurrently
  end
end
