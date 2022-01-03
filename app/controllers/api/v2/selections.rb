module API
  module V2
    class Selections < API::Base
      include API::V2::Defaults

      resource :selections, desc: "Selections (static options)" do
        desc "Frame colors"
        get "/colors" do
          ActiveModel::ArraySerializer.new(Color.all,
            each_serializer: ColorSerializer,
            root: "colors").as_json
        end

        desc "Types of components"
        get "/component_types" do
          ActiveModel::ArraySerializer.new(Ctype.all,
            each_serializer: CtypeSerializer,
            root: "component_types").as_json
        end

        desc "Types of cycles"
        get "/cycle_types" do
          {cycle_types: CycleType.legacy_selections}
        end

        desc "Frame materials"
        get "/frame_materials" do
          {frame_materials: FrameMaterial.legacy_selections}
        end

        desc "Front gear types"
        get "/front_gear_types" do
          {front_gear_types: FrontGearType.all}
        end

        desc "Rear gear types"
        get "/rear_gear_types" do
          {rear_gear_types: RearGearType.all}
        end

        desc "Handlebars"
        get "/handlebar_types" do
          {handlebar_types: HandlebarType.legacy_selections}
        end

        desc "Propulsion types"
        get "/propulsion_types" do
          {propulsion_types: PropulsionType.legacy_selections}
        end

        desc "Wheel sizes (paginated)", {
          notes: <<-NOTE
            We identify wheel sizes by ISO - if you'd like to learn more about ISO, check out [Sheldon Brown's article on tire-sizing](http://sheldonbrown.com/tire-sizing.html#iso).

            We include all the ISO BSD sizes we're familiar with. You can choose get an abbreviated list by passing a `min_popularity`. Since wheel sizes frequently have similar names, we recommend only displaying standard and common sizes.
          NOTE
        }
        paginate
        params do
          optional :min_popularity, type: String, desc: "Minimum commonness of wheel size to include", values: WheelSize.popularities
        end
        get "/wheel_sizes" do
          priority = WheelSize.popularities.index(params[:min_popularity]) || 0
          wheel_sizes = paginate(WheelSize.where("priority  > ?", priority))
          ActiveModel::ArraySerializer.new(wheel_sizes,
            each_serializer: WheelSizeSerializer,
            root: "wheel_sizes").as_json
        end
      end
    end
  end
end
