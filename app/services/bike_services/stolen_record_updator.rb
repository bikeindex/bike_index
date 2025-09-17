class BikeServices::StolenRecordUpdator
  # Used to be in StolenRecord - but now it's here. Eventually, I'd like to actually do permitted params handling in here
  def self.old_attr_accessible
    # recovery_tweet, recovery_share # We edit this in the admin panel
    %i[police_report_number police_report_department locking_description lock_defeat_description
      timezone date_stolen bike creation_organization_id country_id state_id street zipcode city latitude
      longitude theft_description current phone secondary_phone phone_for_everyone
      phone_for_users phone_for_shops phone_for_police receive_notifications proof_of_ownership
      approved recovered_at recovered_description index_helped_recovery can_share_recovery
      recovery_posted tsved_at estimated_value].freeze
  end

  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    b_param = creation_params[:b_param]
    @stolen_params = b_param&.stolen_attrs || {}
  end

  attr_reader :stolen_params

  def update_records
    return if @stolen_params.blank? || @bike.id.blank? # If no bike ID, bike has errored

    @bike.reload
    stolen_record = @bike.fetch_current_stolen_record
    stolen_record ||= @bike.build_new_stolen_record
    stolen_record = update_with_params(stolen_record)
    stolen_record.save
    @bike.reload
    stolen_record
  end

  private

  def update_with_params(stolen_record)
    return stolen_record unless @stolen_params.present?

    stolen_record.attributes = permitted_attributes(@stolen_params)

    if @stolen_params["date_stolen"].present?
      stolen_record.date_stolen = TimeParser.parse(@stolen_params["date_stolen"], @stolen_params["timezone"])
    end

    if @stolen_params["country"].present?
      stolen_record.country = Country.friendly_find(@stolen_params["country"])
    end

    stolen_record.state_id = State.fuzzy_abbr_find(@stolen_params["state"])&.id if @stolen_params["state"].present?
    if @stolen_params["phone_no_show"]
      stolen_record.attributes = {
        phone_for_everyone: false,
        phone_for_users: false,
        phone_for_shops: false,
        phone_for_police: false
      }
    end
    stolen_record
  end

  def permitted_attributes(params)
    ActionController::Parameters.new(params).permit(:phone, :secondary_phone, :street, :city, :zipcode,
      :country_id, :state_id, :police_report_number, :police_report_department, :estimated_value,
      :theft_description, :locking_description, :lock_defeat_description, :proof_of_ownership,
      :receive_notifications, :phone_for_everyone, :phone_for_users,
      :phone_for_shops, :phone_for_police)
  end
end
