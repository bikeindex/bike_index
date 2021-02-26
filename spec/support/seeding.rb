# This is used in multiple places, so add it here
RSpec.shared_context :create_all_colors do
  [
    "Black", "Blue", "Brown", "Green", "Orange", "Pink", "Purple", "Red",
    "Silver, Gray or Bare Metal", "Stickers tape or other cover-up", "Teal",
    "White", "Yellow or Gold"
  ].each { |color| FactoryBot.create(:color, name: color) }
    end
end
