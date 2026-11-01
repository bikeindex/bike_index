# frozen_string_literal: true

module Atoms
  module Admin
    module SectionHeading
      # A section of an admin record's tab, titled with its count - which links to the full index
      class Component < ApplicationComponent
        def initialize(title:, count:, href:)
          @title = title
          @count = count
          @href = href
        end
      end
    end
  end
end
