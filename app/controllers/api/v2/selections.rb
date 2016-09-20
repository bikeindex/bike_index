module API
  module V2
    class Selections < API::Base
      include API::V2::Defaults

      resource :selections, desc: "Selections (static options)" do

        desc "Frame colors"
        get '/colors', root: 'colors' do
          Color.all
        end

        desc "Types of components"
        get '/component_types', each_serializer: CtypeSerializer, root: 'component_types' do 
          Ctype.all
        end

        desc "Types of cycles"
        get '/cycle_types', root: 'cycle_types' do
          CycleType.all
        end

        desc "Frame materials"
        get '/frame_materials', root: 'frame_materials' do
          FrameMaterial.all
        end

        desc "Front gear types"
        get '/front_gear_types', root: 'front_gear_types' do
          FrontGearType.all
        end

        desc "Rear gear types"
        get '/rear_gear_types', root: 'rear_gear_types' do
          RearGearType.all
        end

        desc "Handlebars"
        get '/handlebar_types', root: 'handlebar_types' do
          HandlebarType.all
        end

        desc "Propulsion types"
        get '/propulsion_types', root: 'propulsion_types' do
          PropulsionType.all
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
        get '/wheel_sizes', root: 'wheel_sizes' do
          priority = WheelSize.popularities.index(params[:min_popularity]) || 0
          wheel_sizes = WheelSize.where("priority  > ?", priority)
          paginate wheel_sizes
        end

      end
    end
  end
end
