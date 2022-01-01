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

    enum frame_material: FrameMaterial::SLUGS
    enum handlebar_type: HandlebarType::SLUGS
    enum cycle_type: CycleType::SLUGS
    enum propulsion_type: PropulsionType::SLUGS
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
end
