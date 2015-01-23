module API
  module V2
    class HandlebarTypes < API::V2::Root
      include API::V2::Defaults
      resource :handlebar_types, desc: "Accepted handlebar types" do
        desc "lists of handlebar types"
        get '/', protected: false do
          HandlebarType.scoped
        end
      end

    end
  end
end
