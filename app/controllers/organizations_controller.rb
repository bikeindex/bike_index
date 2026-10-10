class OrganizationsController < ApplicationController
  before_action :set_bparam, only: %i[embed embed_extended]
  before_action :allow_x_frame, only: %i[embed embed_extended embed_create_success]

  def new
    redirect_to new_organization_signup_path
  end

  def lightspeed_interface
    if current_user&.organizations&.any?
      redirect_to("https://posintegration.bikeindex.org?organization_id=#{params[:organization_id]}", allow_other_host: true) && return
    end

    # Signing up makes the account too, so it's where everyone without an organization goes
    flash[:notice] = translation(:must_create_an_organization_first)
    redirect_to new_organization_signup_path(return_to: lightspeed_interface_path)
  end

  # Additional parameter included in shop printouts: shop_display=true
  # currently not used, but may use it someday!
  def embed
    @bike = BikeServices::Builder.build(@b_param)
    @bike.owner_email = params[:email] if params[:email].present?
    @stolen_record = built_stolen_record
    @stolen = @bike.status_stolen?
    @non_stolen = Binxtils::InputNormalizer.boolean(params[:non_stolen]) if !@stolen
    render layout: "embed_layout"
  end

  def embed_extended
    @bike = BikeServices::Builder.build(@b_param)
    if params[:email].present?
      @bike.owner_email = params[:email]
      @persist_email = true unless defined?(@persist_email)
    end
    render layout: "embed_layout"
  end

  def embed_create_success
    find_organization
    @bike = Bike.find_id(params[:bike_id])
    render layout: "embed_layout"
  end

  def qr
    return unless find_organization.present?
    @qr_url = case params[:target]
    when "shop_display" then embed_organization_url(@organization, non_stolen: true, shop_display: true)
    when "landing" then "#{root_url}#{@organization.to_param}" # not routed unless in LandingPageOrganizations::SLUGS
    else new_register_url(organization_id: @organization.to_param)
    end

    qrcode = RQRCode::QRCode.new(@qr_url)
    send_data qrcode.as_png(size: 1200, border_modules: 0).to_s, type: "image/png", disposition: "inline"
  end

  protected

  def set_bparam
    return true unless find_organization.present?

    unless find_organization.auto_user.present?
      flash[:error] = translation(:no_user)
      redirect_to(root_url) && return
    end
    @b_param = if params[:b_param_id_token].present?
      BParam.find_or_new_from_token(params[:b_param_id_token])
    else
      BParam.create(creator_id: @organization.auto_user.id, params: {
        creation_organization_id: @organization.id,
        embeded: true,
        bike: BParam.status_hash_from_params(params)
      })
    end
  end

  def built_stolen_record
    @bike.stolen_records.last || @bike.build_new_stolen_record(@b_param.stolen_attrs)
  end

  def built_stolen_record_date(str)
    DateTime.strptime("#{str} 06", "%m-%d-%Y %H") if str.present?
  rescue ArgumentError
    Time.current
  end

  def find_organization
    @organization = Organization.friendly_find(params[:id])
    return @organization if @organization.present?

    flash[:error] = translation(:not_found)
    redirect_to(root_url) && return
  end
end
