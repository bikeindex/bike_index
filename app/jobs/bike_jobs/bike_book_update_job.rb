module BikeJobs
  class BikeBookUpdateJob < ApplicationJob
    sidekiq_options queue: "high_priority"

    def perform(bike_id)
      bike = Bike.unscoped.find_by(id: bike_id)
      bb_data = bike && Integrations::Bikebook::Data.get_model(bike)
      return if bb_data.blank?

      bb_data["components"].each do |bb_comp|
        attributes = ComponentCreator.new.permitted_attributes(bb_comp)
        component = bike.components.find_by(ctype_id: attributes[:ctype_id]) || bike.components.new
        next unless component.new_record? || component.description == attributes[:description]

        component.update(attributes.merge(is_stock: true, setting_is_stock: true))
      end
    end
  end
end
