class ManufacturerFullSerializer < ActiveModel::Serializer
  attributes :id,
    :name,
    :slug,
    :website,
    :frame_maker,
    :description

end
