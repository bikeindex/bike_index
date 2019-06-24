class Admin::TheftAlertsController < Admin::BaseController
  layout "new_admin"

  before_action :find_theft_alert, only: [:edit, :update]

  # TODO: Add sorting and filtering
  def index
    @theft_alerts =
      TheftAlert
        .includes(:theft_alert_plan)
        .creation_ordered_desc
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  def edit; end

  def update
    case state_transition
    when "begin", "update_details"
      @theft_alert.public_send(
        "#{state_transition}!",
        facebook_post_url: theft_alert_params[:facebook_post_url],
        notes: theft_alert_params[:notes],
      )
    when "end", "reset"
      @theft_alert.public_send("#{state_transition}!")
    end

    if @theft_alert.errors.present?
      flash[:error] = @theft_alert.errors.to_a
      redirect_to edit_admin_theft_alert_path(@theft_alert, params: { state_transition: state_transition })
    else
      flash[:success] = "Success!"
      redirect_to admin_theft_alerts_path
    end
  end

  private

  def find_theft_alert
    @theft_alert = TheftAlert.find(params[:id])
  end

  def theft_alert_params
    params.require(:theft_alert).permit(:facebook_post_url, :notes)
  end

  def state_transition
    return @state_transition if defined?(@state_transition)

    valid_state_transitions = %w[begin end reset update_details]
    state_transition = params[:state_transition]
    return unless state_transition.in?(valid_state_transitions)

    @state_transition = state_transition
  end
end
