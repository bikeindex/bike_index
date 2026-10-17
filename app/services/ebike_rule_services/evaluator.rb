# frozen_string_literal: true

module EbikeRuleServices
  # Checks a bike against a state's law, one row per limit. Each row's status is :pass, :check
  # (legal, with a rule for the rider to follow), :fail or :info, and its note is a symbol
  # naming what the limit means for this bike, with the values that note needs in args
  module Evaluator
    extend Functionable

    def rules(law:, bike:)
      [classes_rule(law, bike), power_rule(law, bike.watts), speed_rule(law, bike),
        throttle_rule(law, bike)]
    end

    # :red if any rule fails, else :yellow if any is to check, else :green - :gray without a law on file
    def verdict(rules)
      return :gray if rules.blank?

      statuses = rules.map { it[:status] }
      return :red if statuses.include?(:fail)

      statuses.include?(:check) ? :yellow : :green
    end

    #
    # private below here
    #

    def row(id, status, note, **args) = {id:, status:, note:, args:}

    def abbreviation(law) = law[:id][EbikeRuleServices::StateLaws::STATE_ID, 1]&.upcase

    # Each class a bike carries has to be recognized
    def classes_rule(law, bike)
      classes = bike.e_bike_classes
      if bike.class_unknown
        row(:classes, :check, :class_unknown)
      elsif bike.e_bike_class.nil?
        row(:classes, :fail, :not_classified)
      elsif bike.out_of_class_in?(abbreviation(law))
        row(:classes, :fail, :classes_not_permitted, e_bike_classes: classes)
      # limits not yet in force describe the coming law, so the rider checks the law's dated rules for today's
      elsif (date = law[:limits_start_on])
        row(:classes, :check, :classes_start_on, date:)
      elsif law[:classes].none?
        row(:classes, :info, :own_classes)
      elsif (unrecognized = classes - law[:classes]).none?
        row(:classes, :pass, :classes_recognized, e_bike_classes: classes)
      elsif (unrecognized - bike.optional_classes.keys).none?
        row(:classes, :check, :optional_classes_not_recognized, e_bike_classes: unrecognized)
      else
        row(:classes, :fail, :classes_not_recognized, e_bike_classes: unrecognized)
      end
    end

    def power_rule(law, watts)
      cap = law[:watt_cap]
      if (date = law[:limits_start_on])
        row(:power, :info, :limits_start_on, date:)
      elsif watts.nil?
        row(:power, :info, :watts_not_provided)
      elsif cap.nil?
        row(:power, :pass, :no_watt_cap)
      elsif watts > cap
        row(:power, :fail, :watts_over_cap, watts:, cap:)
      else
        row(:power, :pass, :watts_within_cap, watts:)
      end
    end

    def speed_rule(law, bike)
      cap = law[:mph]
      mph = bike.top_assist_mph
      past = bike.assists_past_mph
      if (date = law[:limits_start_on])
        row(:speed, :info, :limits_start_on, date:)
      # Class 3's 28 mph, though its record gives its assist a slower top speed
      elsif bike.out_of_class_in?(abbreviation(law))
        row(:speed, :fail, :class_3_speed_with_throttle, mph: [mph, 28].compact.max)
      elsif past && cap
        (cap <= past) ? row(:speed, :fail, :speed_past_cap, past:, cap:) : row(:speed, :check, :speed_past, past:, cap:)
      elsif mph.nil? && past.nil?
        row(:speed, :info, :speed_not_provided)
      elsif cap.nil?
        row(:speed, :pass, :no_speed_cap)
      elsif mph > cap
        row(:speed, :fail, :speed_over_cap, mph:, cap:)
      else
        row(:speed, :pass, :speed_within_cap, mph:)
      end
    end

    # A throttle it's only sold with as an option leaves it legal without one
    def throttle_rule(law, bike)
      rule = throttle_row(law, bike)
      (bike.optional_throttle? && rule[:status] == :fail) ? row(:throttle, :check, :optional_throttle_not_allowed) : rule
    end

    def throttle_row(law, bike)
      return row(:throttle, :pass, :no_throttle) unless bike.throttle
      return row(:throttle, :fail, :throttle_not_allowed) if law[:throttle] == false
      return row(:throttle, :fail, :throttle_with_class_3_assist) if bike.class_3_throttle_banned?(abbreviation(law))
      return row(:throttle, :check, :throttle_not_stated) if law[:throttle].nil?

      case bike.e_bike_class
      when 1 then row(:throttle, :fail, :class_1_throttle)
      when 2 then row(:throttle, :pass, :throttle_allowed)
      when 3 then class_3_throttle(bike.throttle_mph)
      else row(:throttle, :info, :has_throttle)
      end
    end

    # A Class 3's throttle may only take it to Class 2's 20 mph, which the catalog may already record
    def class_3_throttle(mph)
      if mph.nil?
        row(:throttle, :check, :class_3_throttle)
      elsif mph > 20
        row(:throttle, :fail, :class_3_throttle_over, mph:)
      else
        row(:throttle, :pass, :class_3_throttle_within, mph:)
      end
    end

    conceal :row, :abbreviation, :classes_rule, :power_rule, :speed_rule, :throttle_rule, :throttle_row, :class_3_throttle
  end
end
