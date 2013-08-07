class StolenRecordSerializer < ActiveModel::Serializer
  attributes :date_stolen, :latitude, :longitude, :police_report_filed, :theft_description
end
