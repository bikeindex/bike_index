class AddKindToMailSnippets < ActiveRecord::Migration[4.2]
  def change
    add_column :mail_snippets, :kind, :integer, default: 0, null: 0
  end
end
