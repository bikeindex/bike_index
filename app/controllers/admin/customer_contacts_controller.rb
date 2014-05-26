class Admin::CustomerContactsController < Admin::BaseController
  
  def create
    @customer_contact = CustomerContact.new(params[:customer_contact])
    if @customer_contact.save
      flash[:notice] = "Email sent successfully!"
      Resque.enqueue(AdminStolenEmailJob, @customer_contact.id)
      redirect_to edit_admin_stolen_bike_url(@customer_contact.bike_id)
    else
      flash[:error] = "Email send error!\n#{@customer_contact.errors.full_messages.to_sentence}"
      redirect_to edit_admin_stolen_bike_url(@customer_contact.bike_id)
    end
  end

end
