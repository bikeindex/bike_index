class StolenRecordUpdator
  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    @b_param = creation_params[:b_param]
    @stolen_params = isolate_stolen_params(creation_params[:b_param]&.with_indifferent_access)
  end

  attr_reader :stolen_params

  def update_records
    return if @stolen_params.blank?
    @bike.reload
    stolen_record = @bike.fetch_current_stolen_record
    stolen_record ||= @bike.build_new_stolen_record
    stolen_record = update_with_params(stolen_record)
    stolen_record.save
    @bike.reload
    stolen_record
  end

  private

  def isolate_stolen_params(b_param)
    return nil if b_param.blank?
    stolen_params = b_param["stolen_record"] || {}
    nested_params = b_param.dig("bike", "stolen_records_attributes")
    if nested_params&.values&.first&.is_a?(Hash)
      stolen_params = nested_params.values.reject(&:blank?).last
    end
    # Set the date_stolen if it was passed, if something else didn't already set date_stolen
    date_stolen = b_param.dig("bike", "date_stolen")
    stolen_params["date_stolen"] ||= date_stolen if date_stolen.present?
    stolen_params.with_indifferent_access
  end

  def update_with_params(stolen_record)
    return stolen_record unless @stolen_params.present?
    stolen_record.attributes = permitted_attributes(@stolen_params)

    if @stolen_params["date_stolen"].present?
      stolen_record.date_stolen = TimeParser.parse(@stolen_params["date_stolen"], @stolen_params["timezone"])
    end

    if @stolen_params["country"].present?
      stolen_record.country = Country.fuzzy_find(@stolen_params["country"])
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
      :receive_notifications, :show_address)
  end
end
