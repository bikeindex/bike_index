class MailerIntegration
  class << self
    def templates_path
      Rails.root.join('app', 'views', 'mailer_integrations')
    end

    def templates_config
      @templates_config ||= YAML.load_file(Rails.root.join('config', 'mailer_integration_templates.yml'))['templates']
    end

    def template_path(email_name)
      templates_path.join(email_name)
    end

    def template_body(email_name)
      view = ActionView::Base.new(ActionController::Base.view_paths, {})
      view.render(file: template_path(email_name))
    end

    def mailer_class(email_name)
      if %w(partial_registration_email).include?(email_name)
        OrganizedMailer
      else
        CustomerMailer
      end
    end
  end

  def template_config(email_name)
    config = self.class.templates_config.detect { |t| t['name'] == email_name }
    config.present? ? config : (raise ActiveRecord::RecordNotFound)
  end

  def rendered_subject(email_name, args: {})
    str = template_config(email_name).clone['subject']
    str.match(/\{\{[^\}]*\}\}/).to_a.each do |substitution|
      unless args[substitution.delete('{}')].present?
        raise ArgumentError, "Unable to render template, missing subject substitution data #{substitution}"
      end
      str = str.gsub(substitution, args[substitution.delete('{}')])
    end
    str
  end

  def integration_array(email_name:, to_email:, args: {})
    [
      to_email,
      '"Bike Index" <contact@bikeindex.org>',
      rendered_subject(email_name, args: args),
      self.class.template_body(email_name),
      args
    ]
  end
end
