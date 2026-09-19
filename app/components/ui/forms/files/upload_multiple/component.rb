# frozen_string_literal: true

module UI
  module Forms
    module Files
      module UploadMultiple
        # UI::Forms::Files::Upload for an endpoint rather than a form field: every pick goes to `url` in a request
        # of its own, carrying `params`, and the endpoint answers {html:} with the markup for what it
        # stored (or {error:} with why it wouldn't). Already-stored items are the content, and new
        # ones join them where Upload would preview its one.
        class Component < ApplicationComponent
          def initialize(url:, file_param:, params: {}, accept: nil, list_html_options: {})
            @url = url
            @accept = accept
            @data = {"ui--forms--files--picker-params-value": params, "ui--forms--files--picker-file-param-value": file_param}
            @list_html_options = list_html_options
            # No name: nothing submits it, the controller posts its files itself. The id is random so
            # two on a page don't hand both labels the same input
            @input_options = {id: "files_upload_multiple_#{SecureRandom.hex(4)}", multiple: true}
          end
        end
      end
    end
  end
end
