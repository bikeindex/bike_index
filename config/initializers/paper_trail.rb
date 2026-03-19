Rails.application.config.after_initialize do
  PaperTrail::Version.establish_connection :analytics

  PaperTrail::Version.class_eval do
    def save(**options)
      if new_record?
        CreateVersionJob.perform_async(attributes.except("id").compact)
        true
      else
        super
      end
    end
  end
end
