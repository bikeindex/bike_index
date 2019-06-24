class Admin::TheftAlertsController < Admin::BaseController
  layout "new_admin"

  # TODO: Add sorting and filtering
  def index
    @theft_alerts =
      TheftAlert
        .includes(:theft_alert_plan)
        .creation_ordered_desc
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  def edit
    @theft_alert = TheftAlert.find(params[:id])
  end

  def update
    @theft_alert = TheftAlert.find(params[:id])

    case state_transition
    when "begin"
      @theft_alert.begin!(facebook_post_url: theft_alert_params[:facebook_post_url])
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

  def theft_alert_params
    params.require(:theft_alert).permit(:facebook_post_url, :notes)
  end

  def state_transition
    return @state_transition if defined?(@state_transition)

    valid_state_transitions = %w[begin end reset]
    state_transition = params[:state_transition]
    return unless state_transition.in?(valid_state_transitions)

    @state_transition = state_transition
  end
end
