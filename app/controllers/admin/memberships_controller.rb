class Admin::MembershipsController < Admin::BaseController
  before_filter :find_membership, only: [:show, :edit, :update, :destroy]
  before_filter :find_users, only: [:new, :create, :edit]
  before_filter :find_user, only: [:show]
  before_filter :find_organizations
  before_filter :find_organization, only: [:show]

  def index
    @memberships = Membership.all
  end

  def show
  end

  def new
    @membership = Membership.new
  end

  def edit
  end

  def update
    if @membership.update_attributes(params[:membership])
      flash[:notice] = "Membership Saved!"
      redirect_to admin_membership_url(@membership)
    else
      render action: :edit
    end
  end

  def create
    @membership = Membership.new(params[:membership])
    if @membership.save
      flash[:notice] = "Membership Created!"
      redirect_to admin_membership_url(@membership)
    else
      render action: :new
    end
  end

  def destroy
    @membership.destroy
    redirect_to admin_memberships_url
  end

  protected

  def find_membership
    @membership = Membership.find(params[:id])
  end

  def find_users
    @users = User.all
  end

  def find_user
    @user = User.find(@membership[:user_id])
  end
  
  def find_organizations
    @organizations = Organization.all
  end

  def find_organization
    @organization = Organization.find(@membership[:organization_id])
  end
end
