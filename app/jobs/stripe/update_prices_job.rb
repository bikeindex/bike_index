class Stripe::UpdatePricesJob < ApplicationJob
  sidekiq_options retry: 4 # It will retry because of UpdateTheftAlertFacebookJob

  def perform
  end
end
