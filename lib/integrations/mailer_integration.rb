class MailerIntegration
  class << self
    def templates_path
      Rails.root.join('app', 'views', 'mailer_integrations')
    end

    def templates_config
      @templates_config ||= YAML.load_file(Rails.root.join('config', 'mailer_integration_templates.yml'))['templates']
    end

    def template_path(template_name)
      templates_path.join(template_name)
    end

    def template_body(template_name)
      view = ActionView::Base.new(ActionController::Base.view_paths, {})
      view.render(file: template_path(template_name))
    end
  end

  def template_config(template_name)
    config = self.class.templates_config.detect { |t| t['name'] == template_name }
    config.present? ? config : (raise ActiveRecord::RecordNotFound)
  end

  def rendered_subject(template_name, args: {})
    str = template_config(template_name).clone['subject']
    str.match(/\{\{[^\}]*\}\}/).to_a.each do |substitution|
      unless args[substitution.delete('{}')].present?
        raise ArgumentError, "Unable to render template, missing subject substitution data #{substitution}"
      end
      str = str.gsub(substitution, args[substitution.delete('{}')])
    end
    str
  end

  def integration_array(template_name:, to_email:, args: {})
    [
      to_email,
      '"Bike Index" <contact@bikeindex.org>',
      rendered_subject(template_name, args: args),
      self.class.template_body(template_name),
      args
    ]
  end
end
