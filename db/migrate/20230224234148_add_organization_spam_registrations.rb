class AddOrganizationSpamRegistrations < ActiveRecord::Migration[6.1]
  def change
    add_column :organizations, :spam_registrations, :boolean, default: false
    add_column :bikes, :credibility_score, :integer
  end
end
