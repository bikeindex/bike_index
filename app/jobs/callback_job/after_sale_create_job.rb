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
    updator = BikeServices::Updator.new(user: sale.seller, bike: sale.item,
      permitted_params: {bike: {owner_email: sale.new_owner_email}}.as_json)
    updator.update_ownership(sale_id: sale.id)
  end

  def update_marketplace_listing(sale)
    marketplace_listing = sale.marketplace_message&.marketplace_listing
    return unless marketplace_listing.present? && !marketplace_listing.sold?

    marketplace_listing.update(sale:, status: :sold, buyer_id: sale.buyer&.id)
  end
end
