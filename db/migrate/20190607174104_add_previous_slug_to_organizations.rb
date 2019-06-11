class AddPreviousSlugToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :previous_slug, :string
  end
end
