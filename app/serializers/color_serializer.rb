class ColorSerializer < ApplicationSerializer
  attributes :name, :slug, :id, :hex_code

  def hex_code
    object.display
  end
end
