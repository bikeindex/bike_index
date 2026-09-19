# frozen_string_literal: true

module UI
  module Forms
    module FileUploadMultiple
      # FileUpload for an endpoint rather than a form field: every pick goes to `url` in a request
      # of its own, carrying `params`, and the endpoint answers {html:} with the markup for what it
      # stored (or {error:} with why it wouldn't). Already-stored items are the content, and new
      # ones join them where FileUpload would preview its one.
      class Component < UI::Forms::FileUpload::Component
        def initialize(url:, file_param:, params: {}, accept: nil, camera: nil, list_html_options: {})
          super(form_builder: nil, attribute: nil, accept:, camera:)
          @upload_url = url
          @list_data = {"ui--forms--file-upload-params-value": params, "ui--forms--file-upload-file-param-value": file_param}
          @list_html_options = list_html_options
          # Random, so two on a page don't hand both labels the same input
          @input_id = "file_upload_multiple_#{SecureRandom.hex(4)}"
        end

        private

        # No name: nothing submits it, the controller posts its files itself
        def file_input = tag.input(type: "file", id: @input_id, multiple: true, **@html_options)

        def file_label
          label_tag(@input_id, label_content, class: @label_classes, data: {action: "click->ui--forms--file-upload#chooseFile"})
        end
      end
    end
  end
end
