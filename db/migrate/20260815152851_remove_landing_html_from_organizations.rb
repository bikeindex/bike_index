class RemoveLandingHtmlFromOrganizations < ActiveRecord::Migration[8.1]
  def change
    remove_column :organizations, :landing_html, :text
  end
end
