class CallbackJob::AfterSaleCreateJob < ApplicationJob
  sidekiq_options queue: "high_priority"

  def perform(sale_id)
    sale = Sale.find_by_id(sale_id)
    return if sale.blank?

    create_bike_version(sale)
    create_new_ownership(sale)
    update_marketplace_listing(sale)
  end

  private

  def create_bike_version(sale)
    return unless sale.item.is_a?(Bike)

    bike_version = BikeVersionCreatorJob.new.perform(sale.item_id)
    sale.update(item: bike_version)
  end

  def create_new_ownership(sale)
    return if sale.new_ownership.present?

    bike = sale.ownership.bike
    if bike.current_ownership_id == sale.ownership_id
      # It hasn't been updated yet! Transfer the bike
      BikeServices::OwnershipTransferer.find_or_create(bike, updator: sale.seller,
        new_owner_email: sale.new_owner_email, sale_id: sale.id)
    elsif bike.current_ownership&.owner_email == sale.new_owner_email
      # Ownership was transferred to the same person the sale is to -
      # so update the ownership to be
      bike.current_ownership.update(sale_id: sale.id)
    end
  end

  def update_marketplace_listing(sale)
    marketplace_listing = sale.marketplace_message&.marketplace_listing
    return unless marketplace_listing.present? && !marketplace_listing.sold?

    marketplace_listing.update(sale:, status: :sold, buyer_id: sale.buyer&.id)
  end
end
