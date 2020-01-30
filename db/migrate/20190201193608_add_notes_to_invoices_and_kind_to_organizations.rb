class AddNotesToInvoicesAndKindToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :invoices, :notes, :text
    add_column :organizations, :kind, :integer
  end
end
