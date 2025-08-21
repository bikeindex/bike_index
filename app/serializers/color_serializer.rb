# == Schema Information
#
# Table name: colors
#
#  id         :integer          not null, primary key
#  display    :string(255)
#  name       :string(255)
#  priority   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class ColorSerializer < ApplicationSerializer
  attributes :name, :slug, :id, :hex_code

  def hex_code
    object.display
  end
end
