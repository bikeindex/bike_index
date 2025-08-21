# == Schema Information
#
# Table name: locations
#
#  id                       :integer          not null, primary key
#  city                     :string(255)
#  default_impound_location :boolean          default(FALSE)
#  deleted_at               :datetime
#  email                    :string(255)
#  impound_location         :boolean          default(FALSE)
#  latitude                 :float
#  longitude                :float
#  name                     :string(255)
#  neighborhood             :string
#  not_publicly_visible     :boolean          default(FALSE)
#  phone                    :string(255)
#  shown                    :boolean          default(FALSE)
#  street                   :string(255)
#  zipcode                  :string(255)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  country_id               :integer
#  organization_id          :integer
#  state_id                 :integer
#
class LocationSerializer < ApplicationSerializer
  attributes :address, :name, :phone, :street, :city, :country, :state, :zipcode

  def country
    object.country&.name
  end

  def state
    object.state&.name
  end
end
