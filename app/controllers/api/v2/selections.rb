SELECTION_TYPES = {
  "cycle_types" => Class::CycleType,
  "component_types" => Class::Ctype,
  "colors" => Class::Color,
  "handlebar_types" => Class::HandlebarType,
  "frame_materials" => Class::FrameMaterial,
  # stolen_locking_response_suggestions
}
module API
  module V2
    class Selections < API::V2::Root
      include API::V2::Defaults
      resource :selections do
        desc "lists of options for bike attribute selections we provide", {
          notes: <<-NOTE          
          Accepted selections for bikes. Useful to know if you're creating or updating bikes.
          Each `type` will return the `name` and the `slug` for each possible selection. The slug is the url-safe, minimum required parameter you should submit.
          `component_types` also includes a `has_multiple` boolean, which tells whether the component type has multiple on a standard bike. Wheels, for example, `has_multiple`.
          NOTE
        }
        params do 
          requires :type, type: String, desc: 'Selection type', values: SELECTION_TYPES.keys
        end
        get '/', protected: false do
          SELECTION_TYPES[params[:type]].scoped
        end
      end

    end
  end
end
