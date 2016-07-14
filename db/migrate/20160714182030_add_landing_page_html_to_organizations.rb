class AddLandingPageHtmlToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :landing_html, :text
  end
end
