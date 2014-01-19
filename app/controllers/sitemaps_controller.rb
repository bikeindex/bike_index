class SitemapsController < ApplicationController
  caches_page :index
  def index
    @static_paths = ["stolen_bikes", "serials", "about", "manufacturers", "where", "resources", "stolen", "spokecard", "vendor_signup", "contact_us", "documentation/api_v1"]
    @bikes = Bike.scoped
    @blogs = Blog.published
    @manufacturers = Manufacturer.scoped
    @users = User.where(show_bikes: true)
    respond_to do |format|
      format.xml
    end
  end
end
