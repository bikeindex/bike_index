class StolenRecordSerializer < ActiveModel::Serializer
  attributes :date_stolen,
    :latitude,
    :longitude,
    :theft_description,
    :locking_description,
    :lock_defeat_description,
    :police_report_number,
    :police_report_department
end
