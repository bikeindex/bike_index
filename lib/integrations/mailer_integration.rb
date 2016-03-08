class MailerIntegration
  class << self
    def templates_path
      Rails.root.join('app', 'views', 'mailer_integrations')
    end

    def templates_config
      @templates_config ||= read_templates_config
    end

    def read_templates_config
      require 'yaml'
      YAML.load_file(templates_path.join('template_config.yml'))['templates']
    end

    def template_path(template_name)
      templates_path.join("#{template_name}.html.erb")
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

  def integration_array(template_name:, to_email:, args: {})
    [
      to_email,
      '"Bike Index" <contact@bikeindex.org>',
      (args[:title] || template_config(template_name)['title']),
      self.class.template_body(template_name),
      args
    ]
  end
end
