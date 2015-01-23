module API
  module V2
    class ComponentTypes < API::V2::Root
      include API::V2::Defaults
      resource :component_types, desc: "Accepted component types" do
        desc "lists of component types"
        get '/', protected: false, each_serializer: CtypeSerializer, root: 'component_types' do 
          Ctype.scoped
        end
      end

    end
  end
end
