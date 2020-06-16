class AddSubjectAndRemoveNameFromMailSnippets < ActiveRecord::Migration[5.2]
  def change
    add_column :mail_snippets, :subject, :text
    remove_column :mail_snippets, :name, :string
  end
end
