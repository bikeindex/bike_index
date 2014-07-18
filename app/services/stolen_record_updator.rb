class StolenRecordError < StandardError
end

class StolenRecordUpdator
  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    @date_stolen = creation_params[:date_stolen_input]
    @user = creation_params[:user]
    @b_param = creation_params[:new_bike_b_param]
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
    if @bike.stolen_records.any?
      @bike.stolen_records.each do |s|
        s.current = false
        s.save
      end
    end
  end

  def create_date_from_string(date_string)
    DateTime.strptime("#{date_string} 06", "%m-%d-%Y %H")
  end

  def update_records
    if @bike.stolen
      create_new_record unless @bike.current_stolen_record.present?
      if @date_stolen
        stolen_record = @bike.reload.current_stolen_record
        stolen_record.update_attributes(date_stolen: create_date_from_string(@date_stolen))
      end
    else
      @bike.update_attributes(recovered: false) if @bike.recovered == true
      mark_records_not_current
    end
  end

  def set_creation_organization
    @bike.reload.current_stolen_record.update_attributes(creation_organization_id: @bike.creation_organization_id)
  end


  def update_with_params(stolen_record)
    return stolen_record unless @b_param.present? && @b_param.params[:stolen_record].present?
    sr = @b_param.params[:stolen_record]
    stolen_record.police_report_number, stolen_record.police_report_department = [
      sr[:police_report_number], sr[:police_report_department] 
    ]
    stolen_record.theft_description, stolen_record.street, stolen_record.city, stolen_record.zipcode = [
      sr[:theft_description], sr[:street], sr[:city], sr[:zipcode]
    ]
    stolen_record.date_stolen = create_date_from_string(sr[:date_stolen]) if sr[:date_stolen].present?
    stolen_record.country_id = Country.fuzzy_iso_find(sr[:country]).id if sr[:country].present?
    stolen_record.state_id = State.fuzzy_abbr_find(sr[:state]).id if sr[:state].present?
    if sr[:phone_no_show]
    	stolen_record.phone_for_everyone = false
    	stolen_record.phone_for_users = false
    	stolen_record.phone_for_shops = false
    	stolen_record.phone_for_police = false
    end
    stolen_record
  end

  def create_new_record
    mark_records_not_current
    new_stolen_record = StolenRecord.new(bike: @bike, current: true, date_stolen: Time.now)
    if updated_phone.present?
      new_stolen_record.phone = updated_phone
    end
    stolen_record = update_with_params(new_stolen_record)
    if stolen_record.save
      return true
    end
    raise StolenRecordError, "Awww shucks! We failed to mark this bike as stolen. Try again?"
  end

end