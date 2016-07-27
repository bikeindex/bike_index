class BikeBookUpdateWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform(bike_id)
    bike = Bike.unscoped.where(id: bike_id).first
    if bike.present?
      bb_data = BikeBookIntegration.new.get_model(bike)

      if bb_data.present?
        bb_data['components'].each do |bb_comp|
          ctype = Ctype.friendly_find(bb_comp.delete 'component_type')
          component = bike.components.where(ctype_id: ctype.id).first
          if component.present? 
            next unless component.description == bb_comp['description']
          else
            component = Component.new(bike_id: bike.id, ctype_id: ctype.id)
          end
          component.is_stock = true
          component.setting_is_stock = true
          component.update_attributes(ComponentCreator.new.whitelist_attributes(bb_comp))
        end
      end

    end
  end

end