class MailerIntegrationsController < ApplicationController
  layout false

  def show
    template_config = MailerIntegration.new.template_config(params[:id])
    render template_config['name']
  end
end
