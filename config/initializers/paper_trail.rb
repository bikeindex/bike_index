Rails.application.config.after_initialize do
  PaperTrail::Version.establish_connection :analytics

  PaperTrail::Version.class_eval do
    def save!(**options)
      if new_record?
        result = CreateVersionJob.perform_async(attributes.except("id").compact.as_json)
        Rails.logger.info "CreateVersionJob.perform_async result: #{result.inspect}, jobs: #{CreateVersionJob.respond_to?(:jobs) ? CreateVersionJob.jobs.size : 'N/A'}"
        true
      else
        super
      end
    end
  end
end
