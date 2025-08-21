# == Schema Information
#
# Table name: ads
#
#  id              :integer          not null, primary key
#  body            :text
#  image           :string(255)
#  live            :boolean          default(FALSE), not null
#  target_url      :text
#  title           :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :integer
#
require "rails_helper"

RSpec.describe Ad, type: :model do
end
