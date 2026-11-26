# frozen_string_literal: true

module Pages
  module Admin
    module DuplicateBikes
      module ReviewGroups
        # The duplicate dashboard's page of snapshot groups. representatives: the groups' reference bikes by ID,
        # organizations: theirs by ID
        class Component < ApplicationComponent
          def initialize(groups:, representatives:, organizations:, kind:)
            @groups = groups
            @representatives = representatives
            @organizations = organizations
            @kind = kind
          end
        end
      end
    end
  end
end
