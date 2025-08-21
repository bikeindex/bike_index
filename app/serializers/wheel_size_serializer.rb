# == Schema Information
#
# Table name: wheel_sizes
#
#  id          :integer          not null, primary key
#  description :string(255)
#  iso_bsd     :integer
#  name        :string(255)
#  priority    :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class WheelSizeSerializer < ApplicationSerializer
  attributes :iso_bsd, :name, :description, :popularity
end
