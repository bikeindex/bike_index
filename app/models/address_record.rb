# == Schema Information
#
# Table name: address_records
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  city                       :string
#  kind                       :integer
#  latitude                   :float
#  longitude                  :float
#  neighborhood               :string
#  postal_code                :string
#  publicly_visible_attribute :integer
#  region_string              :string
#  street                     :string
#  street_2                   :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  bike_id                    :bigint
#  country_id                 :bigint
#  organization_id            :bigint
#  region_record_id           :bigint
#  user_id                    :bigint
#
# Indexes
#
#  index_address_records_on_bike_id           (bike_id) WHERE (bike_id IS NOT NULL)
#  index_address_records_on_country_id        (country_id)
#  index_address_records_on_organization_id   (organization_id) WHERE (organization_id IS NOT NULL)
#  index_address_records_on_region_record_id  (region_record_id)
#  index_address_records_on_user_id           (user_id) WHERE (user_id IS NOT NULL)
#
class AddressRecord < ApplicationRecord
  include Geocodeable

  KIND_ENUM = {user: 0, bike: 1, marketplace_listing: 2, ownership: 3, organization: 4, impounded_from: 5}.freeze

  enum :kind, KIND_ENUM

  belongs_to :user
  belongs_to :bike
  belongs_to :organization

  has_many :marketplace_listings

  attr_accessor :force_geocoding, :skip_geocoding, :skip_callback_job

  before_validation :set_calculated_attributes
  after_validation :address_record_geocode, if: :should_be_geocoded? # Geocode using our own geocode process
  after_commit :update_associations

  class << self
    def permitted_params
      # user_id and kind should be set manually!
      Geocodeable::ADDRESS_ATTRS
    end

    def default_visibility_for(kind)
      (kind == "organization") ? :street : :postal_code
    end
  end

  # This is used when rendering something with an address that is not the user
  def user_account_address=(val)
    @user_account_address = Binxtils::InputNormalizer.boolean(val)
  end

  def user_account_address
    return @user_account_address if defined?(@user_account_address)

    user&.address_record_id == id
  end

  private

  def update_associations
    # Bikes & ownerships handle address assignment separately
    return if skip_callback_job || %w[bike ownership].include?(kind)

    CallbackJob::AddressRecordUpdateAssociationsJob.perform_async(id)
  end

  def should_be_geocoded?
    return true if force_geocoding
    return false if skip_geocoding

    address_changed?
  end

  def set_calculated_attributes
    self.publicly_visible_attribute ||= self.class.default_visibility_for(kind)
  end
end
