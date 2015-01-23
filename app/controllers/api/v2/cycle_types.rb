module API
  module V2
    class CycleTypes < API::V2::Root
      include API::V2::Defaults
      resource :cycle_types, desc: "Accepted cycle types" do
        desc "lists of cycle types"
        get '/', protected: false do
          CycleType.scoped
        end
      end

    end
  end
end
