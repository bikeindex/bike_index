class Admin::CustomerContactsController < Admin::BaseController
  
  def create
    @customer_contact = CustomerContact.new(permitted_parameters)
    if @customer_contact.save
      flash[:success] = "Email sent successfully!"
      EmailAdminContactStolenWorker.perform_async(@customer_contact.id)
      redirect_to edit_admin_stolen_bike_url(@customer_contact.bike_id)
    else
      flash[:error] = "Email send error!\n#{@customer_contact.errors.full_messages.to_sentence}"
      redirect_to edit_admin_stolen_bike_url(@customer_contact.bike_id)
    end
  end

  private

  def permitted_parameters
    params.require(:customer_contact).permit(:creator_email, :user_email, :title, :contact_type, :creator_id, :bike_id, :body)
  end
end
