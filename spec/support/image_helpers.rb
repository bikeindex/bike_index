require "vips"

module ImageHelpers
  # Mean absolute laplacian. Sharpening is the only step that meaningfully raises a resized
  # image's high-frequency energy, and nothing in the encoded output records that the mask
  # ran - so a comparison only holds against data encoded the same way
  def edge_energy(image_data)
    laplacian = Vips::Image.new_from_array([[0, -1, 0], [-1, 4, -1], [0, -1, 0]])
    Vips::Image.new_from_buffer(image_data, "")
      .colourspace(:"b-w").conv(laplacian, precision: :float).abs.avg
  end
end
