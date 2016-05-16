class StolenRecordError < StandardError
end

class StolenRecordUpdator
  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    @date_stolen = creation_params[:date_stolen_input]
    @user = creation_params[:user]
    @bikeParam = creation_params[:bikeParam]
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
    stolenRecords = StolenRecord.unscoped.where(bike_id: @bike.id)
    if stolenRecords.any?
      stolenRecords.each do |s|
        s.current = false
        s.save
      end
    end
    @bike.update_attribute :current_stolenRecord_id, nil
  end

  def create_date_from_string(date_string)
    return Time.at(date_string) if date_string.kind_of?(Integer)
    DateTime.strptime("#{date_string} 06", '%m-%d-%Y %H')
  end

  def update_records
    if @bike.stolen
      create_new_record unless @bike.find_current_stolenRecord.present?
      if @date_stolen
        stolenRecord = @bike.reload.find_current_stolenRecord
        stolenRecord.update_attributes(date_stolen: create_date_from_string(@date_stolen))
      elsif @bikeParam && @bikeParam[:stolenRecord].present?
        stolenRecord = @bike.reload.find_current_stolenRecord
        update_with_params(stolenRecord).save
      end
    else
      @bike.update_attributes(recovered: false) if @bike.recovered == true
      mark_records_not_current
    end
  end

  def set_creation_organization
    csr = @bike.reload.find_current_stolenRecord
    csr.update_attributes(creation_organization_id: @bike.creation_organization_id)
  end


  def update_with_params(stolenRecord)
    return stolenRecord unless @bikeParam.present? && @bikeParam[:stolenRecord].present?
    sr = @bikeParam[:stolenRecord]
    stolenRecord.police_report_number, stolenRecord.police_report_department = [
      sr[:police_report_number], sr[:police_report_department] 
    ]
    stolenRecord.theft_description, stolenRecord.street, stolenRecord.city, stolenRecord.zipcode = [
      sr[:theft_description], sr[:street], sr[:city], sr[:zipcode]
    ]
    stolenRecord.date_stolen = create_date_from_string(sr[:date_stolen]) if sr[:date_stolen].present?
    if sr[:country].present?
      country = Country.fuzzy_iso_find(sr[:country])
      stolenRecord.country_id = country.id if country.present?
    end
    stolenRecord.state_id = State.fuzzy_abbr_find(sr[:state]).id if sr[:state].present?
    if sr[:phone_no_show]
    	stolenRecord.phone_for_everyone = false
    	stolenRecord.phone_for_users = false
    	stolenRecord.phone_for_shops = false
    	stolenRecord.phone_for_police = false
    end
    stolenRecord.locking_description = sr[:locking_description]
    stolenRecord.lock_defeat_description = sr[:lock_defeat_description]
    stolenRecord
  end

  def create_new_record
    mark_records_not_current
    new_stolenRecord = StolenRecord.new(bike: @bike, current: true, date_stolen: Time.now)
    if updated_phone.present?
      new_stolenRecord.phone = updated_phone
    end
    new_stolenRecord.country_id = Country.united_states.id rescue (raise StolenRecordError, "US isn't instantiated - Stolen Record updater error")
    stolenRecord = update_with_params(new_stolenRecord)
    if stolenRecord.save
      @bike.reload.update_attribute :current_stolenRecord_id, stolenRecord.id
      return true
    end
    raise StolenRecordError, "Awww shucks! We failed to mark this bike as stolen. Try again?"
  end
end