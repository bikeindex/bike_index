# Set the addresses for objects that had the address field added in https://github.com/bikeindex/bike_index/pull/1512

class TemporarySetLocationWorker < ApplicationWorker
  def perform(klass, id)
    if klass == "Bike"
      bike = Bike.unscoped.find(id)
      bike.update_column :address, [bike.city, bike.zipcode, bike.country&.name].select(&:present?).join(" ").presence
    elsif klass == "Location"
      location = Location.unscoped.find(id)
      location.set_address
      location.save
    elsif klass == "StolenRecord"
      stolen_record = StolenRecord.unscoped.find(id)
      stolen_record.set_address
      stolen_record.save
    elsif klass == "User"
      user = User.unscoped.find(id)
      user.set_address
      user.save
    end
  end
end
