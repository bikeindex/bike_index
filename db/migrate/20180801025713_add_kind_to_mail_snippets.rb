class AddKindToMailSnippets < ActiveRecord::Migration
  def change
    add_column :mail_snippets, :kind, :integer, default: 0, null: 0
  end
end
