module AlertImageGenerator
  BASE_TEMPLATE_NAME = "promoted_alert_template.png"
  BASE_TEMPLATE_PATH = Rails.root.join("app", "assets", "images", BASE_TEMPLATE_NAME)
  HEADER_HEIGHT = 100
  FOOTER_HEIGHT = 50
  PADDING = 200

  def self.generate_image(bike_image_path:, bike_url:, bike_location:, output_path:)
    template = MiniMagick::Image.open(BASE_TEMPLATE_PATH)
    container_width = template.width
    container_height = template.height - HEADER_HEIGHT - FOOTER_HEIGHT

    bike = MiniMagick::Image.open(bike_image_path).tap do |b|
      dimensions =
        [container_width, container_height]
          .map { |dim| dim - PADDING }
          .join("x")

      b.resize(dimensions)
    end

    alert_image = template.composite(bike) do |c|
      c.gravity "Center"
      c.compose "Over"
      c.geometry "+0+#{HEADER_HEIGHT - FOOTER_HEIGHT}"
    end

    alert_image.combine_options do |i|
      i.fill "#FFFFFF"
      i.antialias

      if system("mogrify -list font | grep --silent 'Font: Helvetica-Oblique$'")
        i.font "Helvetica-Oblique"
      elsif system("mogrify -list font | grep --silent 'Font: ArialI$'")
        i.font "ArialI"
      end

      # Overlay bike url within lower border
      i.gravity "South"
      i.pointsize 50
      i.draw "text 0,25 '#{bike_url}'"

      # Overlay bike location on RHS of top border
      i.gravity "Northeast"
      i.pointsize 110
      i.size [nil, HEADER_HEIGHT].join("x")
      i.draw "text 30,30 '#{bike_location}'"
    end

    alert_image.write(output_path)
  end
end
