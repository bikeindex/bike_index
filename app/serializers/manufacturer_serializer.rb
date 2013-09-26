class ManufacturerSerializer < ActiveModel::Serializer
  attributes :id,
    :name,
    :slug,
    :website,
    :frame_maker,
    :logo_location,
    :description

end
