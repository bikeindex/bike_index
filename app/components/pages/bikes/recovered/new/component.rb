# frozen_string_literal: true

module Pages
  module Bikes
    module Recovered
      module New
        # The owner telling us the stolen bike is back, and how
        class Component < ApplicationComponent
          # submitted: a submission that was missing its story, re-rendered as entered
          def initialize(bike:, submitted: {})
            @bike = bike
            @submitted = submitted.to_h.with_indifferent_access
          end

          private

          def cycle_type = @bike.type

          def missing_story? = @submitted.present? && @submitted[:story].blank?

          # Stored in the recovered description as the words the owner picked
          def how_options
            [translation(".found_it_myself"), translation(".someone_saw_alert"), translation(".police_recovered"),
              translation(".spotted_for_sale"), translation(".bought_back"), translation(".other")]
          end

          # "Not sure" stores as not helped - the column can't be blank
          def helped_options
            {"true" => translation(".yes_answer"), "false" => translation(".no_answer"), "" => translation(".not_sure")}
          end

          def helped_checked?(value) = @submitted.key?(:index_helped_recovery) && @submitted[:index_helped_recovery] == value

          def recovered_at = @submitted[:recovered_at].presence || Time.current.to_date.iso8601

          def can_share? = !@submitted.key?(:can_share_recovery) || Binxtils::InputNormalizer.boolean(@submitted[:can_share_recovery])
        end
      end
    end
  end
end
