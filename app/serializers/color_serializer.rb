class ColorSerializer < ApplicationSerializer
  attributes :name, :slug

  def slug
    name.downcase.split(/\W+/).first
  end
end
