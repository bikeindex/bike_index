module API
  module V2
    class Selections < API::V2::Root
      include API::V2::Defaults

      resource :selections, desc: "Selections (static options)" do

        desc "Frame colors"
        get '/colors', protected: false, root: 'colors' do
          Color.scoped
        end

        desc "Types of components"
        get '/component_types', protected: false, each_serializer: CtypeSerializer, root: 'component_types' do 
          Ctype.scoped
        end

        desc "Types of cycles"
        get '/cycle_types', protected: false, root: 'cycle_types' do
          CycleType.scoped
        end

        desc "Frame materials"
        get '/frame_materials', protected: false, root: 'frame_materials' do
          FrameMaterial.scoped
        end

        desc "Front gear types"
        get '/front_gear_types', protected: false, root: 'front_gear_types' do
          FrontGearType.scoped
        end

        desc "Rear gear types"
        get '/rear_gear_types', protected: false, root: 'rear_gear_types' do
          RearGearType.scoped
        end

        desc "Handlebars"
        get '/handlebar_types', protected: false, root: 'handlebar_types' do
          HandlebarType.scoped
        end

        desc "Propulsion types"
        get '/propulsion_types', protected: false, root: 'propulsion_types' do
          PropulsionType.scoped
        end
        
        desc "Wheel sizes (paginated)", {
          notes: <<-NOTE
            We identify wheel sizes by ISO - if you'd like to learn more about ISO, check out [Sheldon Brown's article on tire-sizing](http://sheldonbrown.com/tire-sizing.html#iso).

            We include all the ISO BSD sizes we're familiar with. You can choose get an abbreviated list by passing a `min_popularity`. Since wheel sizes frequently have similar names, we recommend only displaying standard and common sizes.
          NOTE
        }
        paginate
        params do 
          optional :min_popularity, type: String, desc: 'Minimum commonness of wheel size to include', values: WheelSize.popularities
        end
        get '/wheel_sizes', protected: false, root: 'wheel_sizes' do
          priority = WheelSize.popularities.index(params[:min_popularity]) || 0
          wheel_sizes = WheelSize.where("priority  > ?", priority)
          paginate wheel_sizes
        end

      end
    end
  end
end
