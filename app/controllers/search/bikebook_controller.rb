# frozen_string_literal: true

module Search
  # The request is the record: LogSearcher reads its params and user from the log line
  class BikebookController < ApplicationController
    def index = head(:no_content)
  end
end
