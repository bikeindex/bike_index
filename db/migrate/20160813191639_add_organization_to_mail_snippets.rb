class AddOrganizationToMailSnippets < ActiveRecord::Migration
  def change
    add_reference :mail_snippets, :organization, index: true
  end
end
