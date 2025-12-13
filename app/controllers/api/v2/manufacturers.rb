module API
  module V2
    class Manufacturers < API::Base
      include API::V2::Defaults

      resource :manufacturers, desc: "Accepted manufacturers" do
        desc "All the manufacturers with pagination"
        paginate
        params do
          optional :only_frame, type: Boolean, desc: "Only include Frame Manufacturers"
        end
        get "/" do
          manufacturers = if Binxtils::InputNormalizer.boolean(params[:only_frame])
            Manufacturer.frame_makers
          else
            Manufacturer
          end.reorder(:name)

          ActiveModel::ArraySerializer.new(paginate(manufacturers),
            each_serializer: ManufacturerSerializer,
            root: "manufacturers").as_json
        end

        desc "Manufacturer matching ID or name", {
          notes: <<-NOTE
            You can request a manufacturer by either their name or their ID
          NOTE
        }
        params do
          requires :id, type: String, desc: "Manufacturer id or slug"
        end
        get ":id" do
          manufacturer = Manufacturer.friendly_find(params[:id])
          unless manufacturer.present?
            msg = "Unable to find manufacturer with name or id: #{params[:id]}"
            raise ActiveRecord::RecordNotFound, msg
          end
          ManufacturerV2ShowSerializer.new(manufacturer, root: "manufacturer").as_json
        end
      end
    end
  end
end
