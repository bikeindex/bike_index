class StolenRecordError < StandardError
end

class StolenRecordUpdator
  def initialize(creation_params = {})
    @bike = creation_params[:bike]
    @date_stolen = creation_params[:date_stolen_input]
    @user = creation_params[:user]
  end

  def create_new_record
    mark_records_not_current
    stolen_record = StolenRecord.new(bike: @bike, current: true, date_stolen: Time.now)     
    stolen_record.phone = updated_phone if updated_phone.present?
    if stolen_record.save
      return true
    end
    raise StolenRecordError, "Damnit! We couldn't mark this bike as stolen. Try again."
  end

  def updated_phone
    if @bike.phone.present?
      phone = @bike.phone 
      if @user.present?
        @user.update_attributes(phone: phone) unless @user.phone
      end
      phone 
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
      mark_records_not_current
    end
  end
end