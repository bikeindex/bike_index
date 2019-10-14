class Admin::ExternalRegistryCredentialsController < Admin::BaseController
  before_action :find_external_registry_credential, only: %i[edit update reset]

  def index
    @external_registry_credentials = ExternalRegistryCredential.all
  end

  def new
    @external_registry_credential = ExternalRegistryCredential.new
  end

  def create
    @external_registry_credential = ExternalRegistryCredential.new(external_registry_credential_params)

    if @external_registry_credential.save
      flash[:info] = "Saved!"
      redirect_to admin_external_registry_credentials_url
    else
      flash[:error] =
        @external_registry_credential.errors.full_messages.to_sentence
      render :new
    end
  end

  def edit; end

  def update
    if @external_registry_credential.update(external_registry_credential_params)
      flash[:info] = "Updated!"
      redirect_to admin_external_registry_credentials_url
    else
      flash[:error] = @external_registry_credential.errors.full_messages.to_sentence
      render :edit
    end
  end

  def reset
    if @external_registry_credential.set_access_token
      flash[:info] = "Access token set!"
    else
      flash[:error] = @external_registry_credential.errors.full_messages.to_sentence
    end

    redirect_to admin_external_registry_credentials_url
  end

  private

  def find_external_registry_credential
    @external_registry_credential = ExternalRegistryCredential.find(params[:id])
  end

  def external_registry_credential_params
    params
      .require(:external_registry_credential)
      .permit(:app_id, :access_token, :refresh_token, :type)
  end
end
