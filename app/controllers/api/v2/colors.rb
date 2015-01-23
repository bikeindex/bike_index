module API
  module V2
    class Colors < API::V2::Root
      include API::V2::Defaults
      resource :colors, desc: "Accepted colors" do
        desc "lists of options for bike frame colors"
        get '/', protected: false do
          Color.scoped
        end
      end

    end
  end
end