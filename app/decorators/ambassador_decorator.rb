class AmbassadorDecorator < ApplicationDecorator
  delegate_all
  alias ambassador object

  ADMIN_VIEWABLE_ATTRIBUTES = %w[
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

  # Return a Hash mapping keys to values for
  # the attributes given by ADMIN_VIEWABLE_ATTRIBUTES
  def admin_viewable_attribute_listing
    attributes.slice(*ADMIN_VIEWABLE_ATTRIBUTES)
  end

  def ambassador_task_assignments
    ambassador
      .ambassador_task_assignments
      .order(created_at: :asc)
  end

  def avatar
    avatar_url = ambassador.avatar&.url(:medium)
    return if avatar_url.blank? || avatar_url == "https://files.bikeindex.org/blank.png"
    h.image_tag avatar_url, class: "users-show-avatar"
  end
end
