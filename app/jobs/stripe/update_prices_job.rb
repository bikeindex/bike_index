class Stripe::UpdatePricesJob < ApplicationJob
  def perform
    membership_products = Stripe::Product.list({active: true, limit: 100})
      .select { _1.name.match?(/member/i) }
    pp membership_products.count

    Stripe::Product.list({active: true, limit: 100}).each do |product|
      # pp product
    end
  end
end
