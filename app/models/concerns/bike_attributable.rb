module BikeAttributable
  extend ActiveSupport::Concern

  included do
    belongs_to :manufacturer
    belongs_to :primary_frame_color, class_name: "Color"
    belongs_to :secondary_frame_color, class_name: "Color"
    belongs_to :tertiary_frame_color, class_name: "Color"
    belongs_to :rear_wheel_size, class_name: "WheelSize"
    belongs_to :front_wheel_size, class_name: "WheelSize"
    belongs_to :rear_gear_type
    belongs_to :front_gear_type

    has_many :public_images, as: :imageable, dependent: :destroy
    has_many :components

    accepts_nested_attributes_for :components, allow_destroy: true

    enum frame_material: FrameMaterial::SLUGS
    enum handlebar_type: HandlebarType::SLUGS
    enum cycle_type: CycleType::SLUGS
    enum propulsion_type: PropulsionType::SLUGS

    scope :with_public_image, -> { joins(:public_images).where.not(public_images: {id: nil}) }
  end

  def frame_colors
    [
      primary_frame_color&.name,
      secondary_frame_color&.name,
      tertiary_frame_color&.name
    ].compact
  end

  # list of cgroups so that we can arrange them
  def cgroup_array
    components.map(&:cgroup_id).uniq
  end

  # Small helper because we call this a lot
  def type
    cycle_type && cycle_type_name&.downcase
  end

  def type_titleize
    return "" unless type.present?
    # make this work for e-scooter
    type.split(/(\s|-)/).map(&:capitalize).join("")
  end

  def frame_model_truncated
    frame_model&.truncate(40)
  end

  def title_string
    t = [year, mnfg_name, frame_model_truncated].join(" ")
    t += " #{type}" if type != "bike"
    Rails::Html::FullSanitizer.new.sanitize(t.gsub(/\s+/, " ")).strip
  end

  def video_embed_src
    return nil unless video_embed.present?
    code = Nokogiri::HTML(video_embed)
    code.xpath("//iframe/@src")[0]&.value
  end

  def render_paint_description?
    return false unless pos? && primary_frame_color == Color.black
    secondary_frame_color_id.blank? && paint.present?
  end

  def paint_description
    paint.name.titleize if paint.present?
  end

  def frame_material_name
    FrameMaterial.new(frame_material).name
  end

  def handlebar_type_name
    HandlebarType.new(handlebar_type)&.name
  end

  def cycle_type_name
    CycleType.new(cycle_type)&.name
  end

  def propulsion_type_name
    PropulsionType.new(propulsion_type).name
  end

  def cached_data_array
    [
      mnfg_name,
      (propulsion_type_name == "Foot pedal" ? nil : propulsion_type_name),
      year,
      frame_colors,
      (frame_material && frame_material_name),
      frame_size,
      frame_model,
      (rear_wheel_size && "#{rear_wheel_size.name} wheel"),
      (front_wheel_size && front_wheel_size != rear_wheel_size ? "#{front_wheel_size.name} wheel" : nil),
      extra_registration_number,
      (cycle_type == "bike" ? nil : type),
      components_cache_array
    ].flatten.reject(&:blank?)
  end

  protected

  def components_cache_array
    components.includes(:manufacturer, :ctype).map do |c|
      c.ctype.present? && c.ctype.name.present? &&
        [c.year, c.manufacturer&.name, c.component_type, c.model_name].compact
    end
  end
end
