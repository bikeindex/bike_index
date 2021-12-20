class AddCreationStateAttrsToOwnership < ActiveRecord::Migration[5.2]
  def change
    # add_reference :ownerships, :organization, index: true
    add_reference :ownerships, :bulk_import, index: true
    # Enums
    add_column :ownerships, :origin, :integer
    add_column :ownerships, :status, :integer
    # Extra stuff
    # add_column :ownerships, :organization_pre_registration, :boolean, default: false
    add_column :ownerships, :owner_name, :string
    add_column :ownerships, :registration_info, :jsonb, default: {}
  end
end
