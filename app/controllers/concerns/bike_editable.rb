module BikeEditable
  extend ActiveSupport::Concern

  included do
    before_action :assign_versions

    helper_method :edit_bike_template_path_for
  end

  def edit_templates
    return @edit_templates if @edit_templates.present?

    @theft_templates = @bike.status_stolen? ? theft_templates : {}
    @bike_templates = bike_templates
    @edit_templates = @theft_templates.merge(@bike_templates)
  end

  def edit_bike_template_path_for(bike, template = nil)
    if bike.version?
      edit_bike_version_url(bike.id, edit_template: template)
    elsif edits_controller_name_for(template) == "edits"
      edit_bike_url(bike.id, edit_template: template)
    elsif template.to_s == "alert"
      new_bike_theft_alert_path(bike_id: bike.id)
    else
      bike_theft_alert_path(bike_id: bike.id)
    end
  end

  protected

  def page_title_for(edit_template, bike)
    "#{edit_templates[edit_template]}: #{bike.title_string}"
  end

  def t_scope
    %i[controllers bikes edit]
  end

  # NB: Hash insertion order here determines how nav links are displayed in the
  # UI. Keys also correspond to template names and query parameters, and values
  # are used as haml header tag text in the corresponding templates.
  def theft_templates
    {}.with_indifferent_access.tap do |h|
      h[:theft_details] = translation(:theft_details, scope: t_scope)
      h[:publicize] = translation(:publicize, scope: t_scope)
      h[:alert] = translation(:alert, scope: t_scope)
      h[:report_recovered] = translation(:report_recovered, scope: t_scope)
    end
  end

  # NB: Hash insertion order here determines how nav links are displayed in the
  # UI. Keys also correspond to template names and query parameters, and values
  # are used as haml header tag text in the corresponding templates.
  def bike_templates
    {}.with_indifferent_access.tap do |h|
      h[:bike_details] = translation(:bike_details, scope: t_scope)
      h[:found_details] = translation(:found_details, scope: t_scope) if @bike.status_found?
      h[:photos] = translation(:photos, scope: t_scope)
      h[:drivetrain] = translation(:drivetrain, scope: t_scope)
      h[:accessories] = translation(:accessories, scope: t_scope)

      unless @bike.version?
        h[:groups] = translation(:groups, scope: t_scope)

        if show_listing_link?(@bike, @current_user)
          h[:marketplace] = if @bike.is_for_sale?
            translation(:marketplace_on_sale, scope: t_scope)
          else
            translation(:marketplace_list, scope: t_scope)
          end
        end
      end

      if show_strava_gear_link?
        h[:strava_gear] = translation(:strava_gear, scope: t_scope)
      end

      h[:remove] = if @bike.version?
        translation(:remove, scope: t_scope)
      else
        translation(:remove_or_transfer, scope: t_scope)
      end

      h[:versions] = translation(:versions, scope: t_scope)
      unless @bike.status_stolen_or_impounded? || @bike.version?
        h[:report_stolen] = translation(:report_stolen, scope: t_scope)
      end
    end
  end

  def setup_edit_template(requested_page = nil)
    @edit_templates = edit_templates
    @permitted_return_to = permitted_return_to

    # If provided an invalid template name, redirect to the default page for a stolen /
    # unstolen bike
    @edit_template = requested_page || @bike.default_edit_template
    valid_requested_page = (edit_templates.keys.map(&:to_s) + ["alert_purchase_confirmation"]).include?(@edit_template)
    unless valid_requested_page && controller_name == edits_controller_name_for(@edit_template)
      edit_redirect_url = if @edit_template == "ownership" && params[:owner_email].present? # Preserve older functionality
        edit_bike_url(@bike.id, edit_template: "remove", owner_email: params[:owner_email])
      else
        redirect_template = valid_requested_page ? @edit_template : @bike.default_edit_template
        edit_bike_template_path_for(@bike, redirect_template)
      end

      redirect_to(edit_redirect_url)
      return false
    end

    @skip_general_alert = %w[photos theft_details report_recovered remove alert alert_purchase_confirmation].include?(@edit_template)
    true
  end

  def show_strava_gear_link?
    return false if @bike.version?
    @current_user&.strava_integration&.synced? && @current_user.strava_integration.athlete_gear.present?
  end

  def show_listing_link?(bike, user)
    return false unless bike.status_with_owner?
    return true if bike.current_marketplace_listing&.current?

    user&.can_create_listing?
  end

  def assign_versions
    return true unless @bike.present?

    @bike_og ||= @bike # Already assigned by bike_versions controller
    @bike_versions = @bike_og.bike_versions.where(owner_id: @current_user&.id)
  end

  def edits_controller_name_for(requested_page)
    %w[alert alert_purchase_confirmation].include?(requested_page.to_s) ? "theft_alerts" : "edits"
  end
end
