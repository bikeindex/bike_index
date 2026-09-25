# frozen_string_literal: true

class ShopifyIntegrationsController < ApplicationController
  include Sessionable

  before_action :authenticate_user_for_shopify
  before_action :find_organization, except: %i[callback]

  def new
    @shopify_integration = @organization.shopify_integration
  end

  def create
    shop_domain = ShopifyIntegration.normalize_shop_domain(params[:shop_domain])
    if shop_domain.blank?
      flash[:error] = "Enter your Shopify store address, e.g. your-store.myshopify.com"
      redirect_to(new_shopify_integration_path(organization_id: @organization.to_param)) && return
    end

    state = SecureRandom.hex(24)
    session[:shopify_oauth] = {"state" => state, "organization_id" => @organization.id,
                               "shop_domain" => shop_domain}
    redirect_to Integrations::Shopify::Client.authorization_url(shop_domain:, state:),
      allow_other_host: true
  end

  def callback
    oauth = session.delete(:shopify_oauth) || {}
    organization = Organization.friendly_find(oauth["organization_id"])
    return_to = organization.present? ? organization_manage_path(organization_id: organization.to_param) : my_account_path

    error = callback_error(oauth, organization)
    if error.present?
      flash[:error] = error
      redirect_to(return_to) && return
    end

    token_data = Integrations::Shopify::Client.exchange_token(shop_domain: oauth["shop_domain"], code: params[:code])
    if token_data.blank?
      flash[:error] = "Unable to connect to Shopify. Please try again."
      redirect_to(return_to) && return
    end

    shopify_integration = create_shopify_integration(organization, oauth["shop_domain"], token_data)
    ShopifyJobs::RegisterWebhooksJob.perform_async(shopify_integration.id)
    flash[:success] = "#{shopify_integration.shop_domain} connected! New sales with a serial in the notes will be registered."
    redirect_to return_to
  end

  def destroy
    @organization.shopify_integration&.destroy
    flash[:success] = "Shopify integration removed."
    redirect_to organization_manage_path(organization_id: @organization.to_param)
  end

  private

  def authenticate_user_for_shopify
    store_return_and_authenticate_user(flash_type: :notice)
  end

  def find_organization
    @organization = Organization.friendly_find(params[:organization_id])
    return true if @organization.present? && current_user.admin_of?(@organization)

    flash[:error] = "You have to be an admin of that organization to do that."
    redirect_to my_account_path
  end

  # The shop is only trustworthy because Shopify signed the callback - taking the bare `shop`
  # param would let anyone point an organization at a store they don't own
  def callback_error(oauth, organization)
    return "Shopify authorization was denied." if params[:error].present?
    return "Invalid OAuth state. Please try again." unless Binxtils::Secure.compare?(params[:state].to_s, oauth["state"].to_s)
    return "Invalid OAuth state. Please try again." unless Integrations::Shopify::Client.verified_callback?(params)
    return "Invalid OAuth state. Please try again." unless params[:shop] == oauth["shop_domain"]
    return "You have to be an admin of that organization to do that." unless organization.present? && current_user.admin_of?(organization)

    nil
  end

  def create_shopify_integration(organization, shop_domain, token_data)
    organization.shopify_integration&.destroy
    ShopifyIntegration.create!(organization:, user: current_user, shop_domain:,
      access_token: token_data["access_token"], scopes: token_data["scope"])
  end
end
