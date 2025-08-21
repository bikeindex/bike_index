# == Schema Information
#
# Table name: rear_gear_types
#
#  id         :integer          not null, primary key
#  count      :integer
#  internal   :boolean          default(FALSE), not null
#  name       :string(255)
#  slug       :string(255)
#  standard   :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "rails_helper"

RSpec.describe RearGearType, type: :model do
end
