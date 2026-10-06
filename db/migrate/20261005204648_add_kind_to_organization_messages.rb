class AddKindToOrganizationMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :organization_messages, :kind, :integer, default: 0, null: false
  end
end
