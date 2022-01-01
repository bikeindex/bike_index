class BikeVersionsController < ApplicationController
  before_action :render_ad, only: %i[index show]
  before_action :find_bike_version, except: %i[index new create]
  before_action :ensure_user_allowed_to_edit, except: %i[index show new create]

  def index
  end

  def show
  end

  def new
  end

  def create
  end

  def update
  end

  protected

  def find_bike_version
    begin
      @bike_version = BikeVersion.unscoped.find(params[:id])
    rescue ActiveRecord::StatementInvalid => e
      raise e.to_s.match?(/PG..NumericValueOutOfRange/) ? ActiveRecord::RecordNotFound : e
    end
    return @bike_version if @bike_version.visible_by?(current_user)
    fail ActiveRecord::RecordNotFound
  end

  def ensure_user_allowed_to_edit
    return true if @bike_version.authorized?(current_user)
  end

  def render_ad
    @ad = true
  end
end
