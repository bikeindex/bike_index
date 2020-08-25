class RemoveAddressColumnFromMailSnippets < ActiveRecord::Migration[5.2]
  def change
    remove_column :mail_snippets, :address, :string
  end
end
