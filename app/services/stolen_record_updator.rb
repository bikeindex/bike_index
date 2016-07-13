class StolenRecordError < StandardError
end

class StolenRecordUpdator
  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    @date_stolen = creation_params[:date_stolen_input]
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

  def create_date_from_string(date_string)
    return Time.at(date_string) if date_string.kind_of?(Integer)
    DateTime.strptime("#{date_string} 06", '%m-%d-%Y %H')
  end

  def create_date_from_input(date_formatted)
    DateTime.strptime("#{date_formatted} 06", StolenRecord.revised_date_format_hour)
  end

  def update_records
    if @bike.stolen
      create_new_record unless @bike.find_current_stolen_record.present?
      @bike.reload
      if @date_stolen
        stolen_record = @bike.find_current_stolen_record
        stolen_record.update_attributes(date_stolen: create_date_from_string(@date_stolen))
      elsif @b_param && (@b_param['stolen_record'] || @b_param['bike']['stolen_records_attributes'])
        stolen_record = @bike.find_current_stolen_record
        update_with_params(stolen_record).save
      end
    else
      @bike.update_attributes(recovered: false) if @bike.recovered == true
      mark_records_not_current
    end
  end

  def set_creation_organization
    csr = @bike.reload.find_current_stolen_record
    csr.update_attributes(creation_organization_id: @bike.creation_organization_id)
  end


  def update_with_params(stolen_record)
    @b_param['stolen_record'] = @b_param['bike']['stolen_records_attributes'][stolen_record.id.to_s] if @b_param && @b_param['bike'] && @b_param['bike']['stolen_records_attributes']
    return stolen_record unless @b_param.present? && @b_param['stolen_record'].present?
    sr = @b_param['stolen_record']
    stolen_record.attributes = permitted_attributes
    stolen_record.date_stolen = create_date_from_string(sr['date_stolen']) if sr['date_stolen']
    stolen_record.date_stolen = create_date_from_input(sr['date_stolen_input']) if sr['date_stolen_input']
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
    new_stolen_record = StolenRecord.new(bike: @bike, current: true, date_stolen: Time.now)
    if updated_phone.present?
      new_stolen_record.phone = updated_phone
    end
    new_stolen_record.country_id = Country.united_states.id rescue (raise StolenRecordError, "US isn't instantiated - Stolen Record updater error")
    stolen_record = update_with_params(new_stolen_record)
    if stolen_record.save
      @bike.reload.update_attribute :current_stolen_record_id, stolen_record.id
      return true
    end
    raise StolenRecordError, "Awww shucks! We failed to mark this bike as stolen. Try again?"
  end

  def permitted_attributes
    ActionController::Parameters.new(@b_param['stolen_record']).permit(*permitted_params)
  end

  private

  def permitted_params
    %w(phone secondary_phone street city zipcode country_id state_id
       police_report_number police_report_department
       theft_description locking_description lock_defeat_description
       proof_of_ownership receive_notifications)
  end
end