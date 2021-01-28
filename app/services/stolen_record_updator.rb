class StolenRecordUpdator
  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    if creation_params[:date_stolen].present?
      @date_stolen = TimeParser.parse(creation_params[:date_stolen])
    end
    @user = creation_params[:user]
    @b_param = creation_params[:b_param]
    @mark_bike_stolen = creation_params[:mark_bike_stolen]
  end

  def update_records
    if @mark_bike_stolen
      create_new_record
      @bike.reload
    elsif @bike.stolen
      if @date_stolen
        stolen_record = @bike.fetch_current_stolen_record
        stolen_record.update_attributes(date_stolen: @date_stolen)
      elsif @b_param && (@b_param["stolen_record"] || @b_param["bike"]["stolen_records_attributes"])
        stolen_record = @bike.fetch_current_stolen_record
        update_with_params(stolen_record).save
      end
    else
      @bike.update_attributes(abandoned: false) if @bike.abandoned == true
    end
  end

  def create_new_record
    stolen_record = @bike.build_new_stolen_record(date_stolen: @date_stolen)
    stolen_record = update_with_params(stolen_record)
    stolen_record.save
    stolen_record
  end

  private

  def update_with_params(stolen_record)
    return stolen_record unless @b_param.present?

    sr = @b_param["stolen_record"]
    nested_params = @b_param.dig("bike", "stolen_records_attributes")
    sr = nested_params.values.reject(&:blank?).last if nested_params&.values&.first&.is_a?(Hash)
    return stolen_record unless sr.present?
    stolen_record.attributes = permitted_attributes(sr)

    if sr["date_stolen"].present?
      stolen_record.date_stolen = TimeParser.parse(sr["date_stolen"], sr["timezone"])
    end

    if sr["country"].present?
      stolen_record.country = Country.fuzzy_find(sr["country"])
    end

    stolen_record.state_id = State.fuzzy_abbr_find(sr["state"])&.id if sr["state"].present?
    if sr["phone_no_show"]
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
