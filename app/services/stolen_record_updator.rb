class StolenRecordError < StandardError
end

class StolenRecordUpdator
  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    @date_stolen = TimeParser.parse(creation_params[:date_stolen])
    @user = creation_params[:user]
    @b_param = creation_params[:b_param]
  end 

  def updated_phone
    if @bike.phone.present?
      phone = @bike.phone 
      if @user.present?
        @user.update_attributes(phone: phone) unless @user.phone
      end
      return phone 
    end
  end

  def mark_records_not_current
    stolen_records = StolenRecord.unscoped.where(bike_id: @bike.id)
    if stolen_records.any?
      stolen_records.each do |s|
        s.current = false
        s.save
      end
    end
    @bike.update_attribute :current_stolen_record_id, nil
  end

  def update_records
    if @bike.stolen
      if @bike.find_current_stolen_record.blank?
        create_new_record
        @bike.reload
      elsif @date_stolen
        stolen_record = @bike.find_current_stolen_record
        stolen_record.update_attributes(date_stolen: @date_stolen)
      elsif @b_param && (@b_param['stolen_record'] || @b_param['bike']['stolen_records_attributes'])
        stolen_record = @bike.find_current_stolen_record
        update_with_params(stolen_record).save
      end
    else
      @bike.update_attributes(recovered: false) if @bike.recovered == true
      mark_records_not_current
    end
  end

  def update_with_params(stolen_record)
    return stolen_record unless @b_param.present?
    sr = @b_param['stolen_record']
    if @b_param['bike'] && @b_param['bike']['stolen_records_attributes'] && @b_param['bike']['stolen_records_attributes'].values.first.is_a?(Hash)
      @b_param['bike']['stolen_records_attributes'].each { |k, v| sr = v if v.present? }
    end
    return stolen_record unless sr.present?
    stolen_record.attributes = permitted_attributes(sr)

    unless @date_stolen.present?
      stolen_record.date_stolen = TimeParser.parse(sr["date_stolen"], sr["timezone"]) || Time.now
    end
    if sr['country'].present?
      country = Country.fuzzy_iso_find(sr['country'])
      stolen_record.country_id = country.id if country.present?
    end
    stolen_record.state_id = State.fuzzy_abbr_find(sr['state']).id if sr['state'].present?
    if sr['phone_no_show']
    	stolen_record.attributes = {
        phone_for_everyone: false,
      	phone_for_users: false,
      	phone_for_shops: false,
      	phone_for_police: false
      }
    end
    stolen_record
  end

  def create_new_record
    mark_records_not_current
    new_stolen_record = StolenRecord.new(bike: @bike, current: true, date_stolen: @date_stolen || Time.now)
    if updated_phone.present?
      new_stolen_record.phone = updated_phone
    end
    new_stolen_record.country_id = Country.united_states.id rescue (raise StolenRecordError, "US isn't instantiated - Stolen Record updater error")
    stolen_record = update_with_params(new_stolen_record)
    stolen_record.creation_organization_id = @bike.creation_organization_id
    if stolen_record.save
      @bike.reload.update_attribute :current_stolen_record_id, stolen_record.id
      return true
    end
    raise StolenRecordError, "Awww shucks! We failed to mark this bike as stolen. Try again?"
  end

  def permitted_attributes(params)
    ActionController::Parameters.new(params).permit(*permitted_params)
  end

  private

  def permitted_params
    %w(phone secondary_phone street city zipcode country_id state_id
       police_report_number police_report_department estimated_value
       theft_description locking_description lock_defeat_description
       proof_of_ownership receive_notifications)
  end
end