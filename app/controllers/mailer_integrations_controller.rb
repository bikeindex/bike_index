class MailerIntegrationsController < ApplicationController
  def show
    template_config = MailerIntegration.new.template_config(params[:id])
    render template_config['name'], layout: false
  end

  def index
    @show_substitution_values = params[:show_substitution_values]
    render layout: 'application_updated'
  end
end
