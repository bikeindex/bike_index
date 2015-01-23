module API
  module V2
    class FrameMaterials < API::V2::Root
      include API::V2::Defaults
      resource :frame_materials, desc: "Accepted frame materials" do
        desc "lists of options for frame materials we recognize"
        get '/', protected: false do
          FrameMaterial.scoped
        end
      end
    end
  end
end
