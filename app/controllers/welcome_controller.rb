class WelcomeController < ApplicationController
  def index
    render action: 'index', layout: (revised_layout_enabled? ? 'application_revised' : 'application_updated')
  end

  def update_browser
    render action: 'update_browser', layout: false
  end

  def goodbye
    if current_user.present?
      redirect_to logout_url
    else
      render action: 'goodbye', layout: (revised_layout_enabled? ? 'application_revised' : 'application')
    end
  end

  def user_home
    if current_user.present?
      @user = current_user
      bikes = current_user.bikes
      page = params[:page] || 1
      @per_page = params[:per_page] || 20
      paginated_bikes = Kaminari.paginate_array(bikes).page(page).per(@per_page)
      @bikes = BikeDecorator.decorate_collection(paginated_bikes)
      @locks = LockDecorator.decorate_collection(current_user.locks)
      if revised_layout_enabled?
        render :revised_user_home, layout: 'application_revised'
      else
        render action: 'user_home', layout: 'no_container'
      end
    else
      redirect_to new_user_url
    end
  end

  def choose_registration
    @user = User.new unless current_user.present?
  end
end
