class ExternalRegistry < ActiveRecord::Base
  validates :name, :url, presence: true
  has_many :external_registry_bikes
end
