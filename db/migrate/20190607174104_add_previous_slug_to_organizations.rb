class AddPreviousSlugToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :previous_slug, :string
  end
end
