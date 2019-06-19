class Admin::TheftAlertsController < Admin::BaseController
  layout "new_admin"

  def index
    @theft_alerts = TheftAlert.includes(:theft_alert_plan).all
  end

  def edit
    @theft_alert = TheftAlert.find(params[:id])

    case state_transition
    when "begin"
      render :edit
    else
      flash[:error] = "Invalid state transition."
      redirect_to admin_theft_alerts_path
    end
  end

  def update
    @theft_alert = TheftAlert.find(params[:id])
    @theft_alert.public_send("#{state_transition}!", theft_alert_params)

    if @theft_alert.errors.present?
      flash[:error] = @theft_alert.errors.to_a
      redirect_to edit_admin_theft_alert_path(@theft_alert, params: { state_transition: state_transition })
    else
      flash[:success] = "Success!"
      redirect_to admin_theft_alerts_path
    end
  end

  private

  def theft_alert_params
    params.require(:theft_alert).permit(:facebook_post_url)
  end

  def state_transition
    return @state_transition if defined?(@state_transition)

    valid_state_transitions = %w[begin end reset]
    state_transition = params[:state_transition]
    return unless state_transition.in?(valid_state_transitions)

    @state_transition = state_transition
  end
end
