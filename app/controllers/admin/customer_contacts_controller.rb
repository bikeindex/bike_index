class Admin::CustomerContactsController < Admin::BaseController
  
  def create
    @customer_contact = CustomerContact.new(params[:customer_contact])
    if @customer_contact.save
      flash[:notice] = "Email sent successfully!"
      Resque.enqueue(AdminStolenEmailJob, @customer_contact.id)
      redirect_to edit_admin_stolen_bike_url(@customer_contact.bike_id)
    else
      flash[:error] = "Email send error!"
      pp @customer_contact.errors
      redirect_to edit_admin_stolen_bike_url(@customer_contact.bike_id)
    end
  end

end
