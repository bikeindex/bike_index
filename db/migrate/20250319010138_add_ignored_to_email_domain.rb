class AddIgnoredToEmailDomain < ActiveRecord::Migration[8.0]
  def change
    add_column :email_domains, :ignored, :boolean, default: false
  end
end
