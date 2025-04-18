class Admin::CustomerContactsController < Admin::BaseController
  def show
    @customer_contact = CustomerContact.find(params[:id])
  end

  def create
    @customer_contact = CustomerContact.new(permitted_parameters)
    if @customer_contact.save
      flash[:success] = "Email sent successfully!"
      Email::AdminContactStolenJob.perform_async(@customer_contact.id)
    else
      flash[:error] = "Email send error!\n#{@customer_contact.errors.full_messages.to_sentence}"
    end
    redirect_to edit_admin_stolen_bike_url(@customer_contact.bike_id)
  end

  private

  def permitted_parameters
    params.require(:customer_contact).permit(
      :bike_id,
      :body,
      :creator_email,
      :creator_id,
      :kind,
      :title,
      :user_email
    )
  end
end
