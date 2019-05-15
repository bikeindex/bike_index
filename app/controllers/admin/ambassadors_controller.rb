class Admin::AmbassadorsController < Admin::BaseController
  layout "new_admin"

  USER_ATTRIBUTES = %w[
    id
    email
    name
    phone
    username
    stripe_id
    title
    twitter
    website
    street
    city
    state_id
    country_id
    zipcode
    latitude
    longitude
    last_login
    updated_at
    created_at
  ].freeze

  def index
    @page = params.fetch(:page, 1)
    @per_page = params.fetch(:per_page, 25)
    @ambassadors = Ambassador.all.page(@page).per(@per_page)
  end

  def show
    @ambassador = Ambassador.find(params[:id])
    @ambassador_attributes = @ambassador.attributes.slice(*USER_ATTRIBUTES)
  end
end
