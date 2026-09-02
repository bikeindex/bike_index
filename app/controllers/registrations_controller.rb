class RegistrationsController < ApplicationController
  before_action :allow_x_frame, except: %i[new show]
  skip_before_action :verify_authenticity_token, only: [:create] # Because it was causing issues, and we don't need it here
  before_action :simple_header, except: %i[show edit]
  around_action :set_reading_role, only: %i[show]
  layout "reg_embed"

  def show
    @bike = Bike.unscoped.find_id(params[:id])
    fail ActiveRecord::RecordNotFound unless @bike.visible_by?(current_user)

    requested_view = view_from_param(params[:view_as])
    available_views = BikeServices::ShowViews.available(bike: @bike, current_user:,
      organization: current_organization || passive_organization, preview_organization: requested_view&.last)

    view = current_view(available_views, requested_view)
    # So the view_as organization sticks on the next request
    set_passive_organization(view.last) if view.last

    bike_sticker = BikeSticker.lookup_with_fallback(params[:scanned_id],
      organization_id: params[:organization_id], user: current_user)

    render(Pages::Registrations::Show::Wrapper::Component.new(bike: @bike, current_user:, view:,
      available_views:, bike_sticker:, current_alerts:, display_dev_info: display_dev_info?), layout: "application")
  end

  # The redesign has no edit view of its own; edit still lives on the bike
  def edit
    redirect_to edit_bike_path(params[:id], request.query_parameters)
  end

  def new
    @stolen = params[:stolen] # Passed into embed form
    render layout: "application"
  end

  # Attributes assigned in the partial, but can be overridden so it can be used anywhere
  def embed
    @organization = current_organization
    @owner_email = current_user&.email
    @selectable_child_organizations = find_selectable_child_organizations
    creation_organization_id = @selectable_child_organizations.any? ? nil : @organization&.id
    @button_and_header = HexColor.normalize(params[:button_and_header])
    @button = HexColor.normalize(params[:button])
    if @b_param.blank?
      bike_params = {creation_organization_id: creation_organization_id, owner_email: @owner_email}
        .merge(BParam.status_hash_from_params(params))
      @b_param = BParam.new(params: {bike: bike_params.as_json})
    end
    @stolen = @b_param.status_stolen?
    @vehicle_select = !Binxtils::InputNormalizer.boolean(params[:skip_vehicle_select])
  end

  def create
    @b_param = BParam.new(permitted_params)
    @b_param.errors.add :owner_email, "required" unless @b_param.owner_email.present?
    if @b_param.errors.blank? && @b_param.save
      Email::PartialRegistrationJob.perform_async(@b_param.id)
    else
      @page_errors = @b_param.errors
      render action: :new
    end
  end

  private

  # Both session touches mirror the legacy bikes#show: the recovery token is spent as
  # it's read, and a matching claim token records the email so signing up can claim
  def current_alerts
    alerts = BikeServices::ShowCurrentAlerts.find(bike: @bike, params:,
      recovery_link_token: session.delete(:recovery_link_token))
    if alerts[:claim_message].present?
      session[:claim_token_email] = @bike.current_ownership.owner_email
    end
    alerts
  end

  # The resolved [kind, organization] perspective (e.g. [:public, nil] or
  # [:staff, organization]). A ?view_as param overrides the default, but only to a
  # perspective the user is allowed — otherwise it flashes and falls back.
  def current_view(available_views, requested_view)
    if params[:view_as].present? && !available_views.include?(requested_view)
      flash.now[:error] = "You're not allowed to view this registration that way"
      requested_view = nil
    end
    requested_view || BikeServices::ShowViews.default_view_for(bike: @bike, current_user:, organization: current_organization || passive_organization)
  end

  # The [kind, organization] view requested via ?view_as, or nil when absent/unknown.
  # A bare org slug (no explicit role) resolves to the user's own role for the org.
  def view_from_param(param)
    case param
    when "public" then [:public, nil]
    when "owner" then [:owner, nil]
    when nil, "" then nil
    else
      slug, role = param.split(".", 2)
      org = Organization.friendly_find(slug)
      return nil unless org

      role ||= current_user&.member_bike_edit_of?(org) ? "staff" : "limited"
      [(role == "limited") ? :limited : :staff, org]
    end
  end

  def simple_header
    @simple_header ||= Binxtils::InputNormalizer.boolean(params[:simple_header])
  end

  def find_selectable_child_organizations
    return [] unless @organization.present? && Binxtils::InputNormalizer.boolean(params[:select_child_organization])

    @organization.child_organizations
  end

  def permitted_params
    params.require(:b_param).permit(:creation_organization_id,
      :cycle_type,
      :manufacturer_id,
      :owner_email,
      :primary_frame_color_id,
      :secondary_frame_color_id,
      :status,
      :tertiary_frame_color_id)
      .merge(
        origin: "embed_partial",
        propulsion_type_motorized: params[:propulsion_type_motorized]
      )
  end
end
