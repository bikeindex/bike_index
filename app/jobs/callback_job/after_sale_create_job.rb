class CallbackJob::AfterSaleCreateJob < ApplicationJob
  sidekiq_options queue: "high_priority"

  def perform(sale_id)
    sale = Sale.find_by_id(sale_id)
    return if sale.blank?

    create_new_ownership(sale)
    update_marketplace_listing(sale)
  end

  private

  def create_new_ownership(sale)
    return if sale.new_ownership.present?

    if sale.item.current_ownership_id == sale.ownership_id
      # It hasn't been updated yet! Transfer the bike
      BikeServices::OwnershipTransferer.find_or_create(sale.item, updator: sale.seller,
        new_owner_email: sale.new_owner_email, sale_id: sale.id)
    elsif sale.item.current_ownership&.owner_email == sale.new_owner_email
      # Ownership was transferred to the same person the sale is to -
      # so update the ownership to be
      sale.item.current_ownership.update(sale_id: sale.id)
    end
  end

  def update_marketplace_listing(sale)
    marketplace_listing = sale.marketplace_message&.marketplace_listing
    return unless marketplace_listing.present? && !marketplace_listing.sold?

    marketplace_listing.update(sale:, status: :sold, buyer_id: sale.buyer&.id)
  end
end
