class SitemapsController < ApplicationController
  caches_page :index
  def index
    @static_paths = ["stolen_bikes", "serials", "about", "who", "where", "shops", "security", "resources", "stolen", "spokecard", "manufacturers", "vendor_signup", "contact_us"]
    @bikes = Bike.all
    @blogs = Blog.all
    @users = User.where(show_bikes: true)
    respond_to do |format|
      format.xml
    end
  end
end
