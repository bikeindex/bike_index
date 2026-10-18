# frozen_string_literal: true

module EbikeRuleServices
  # Checks a bike against a state's law, one row per limit. Each row's status is :pass, :check
  # (legal, with a rule for the rider to follow), :fail or :info, and its note is a symbol
  # naming what the limit means for this bike, with the values that note needs in args
  module Evaluator
    extend Functionable

    # A law outside the US sets limits, in km/h, rather than classes. One a motor vehicle's, where an e-bike falls in
    # with them, comes with its licence and registration rules to check
    def rules(law:, bike:)
      if law[:metric]
        [(row(:vehicle, :check, :no_e_bike_category) if law[:motor_vehicle]), power_rule(law, bike.watts),
          metric_speed_rule(law, bike), throttle_rule(law, bike)].compact
      else
        [classes_rule(law, bike), power_rule(law, bike.watts), speed_rule(law, bike), throttle_rule(law, bike)]
      end
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

    # Each class a bike carries has to be recognized
    def classes_rule(law, bike)
      classes = bike.e_bike_classes
      if bike.class_unknown
        row(:classes, :check, :class_unknown)
      elsif bike.e_bike_class.nil?
        row(:classes, :fail, :not_classified)
      elsif bike.out_of_class_under?(law)
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
      # outside the US, a cap under the 750W many e-bikes are rated
      elsif watts.nil? && law[:metric] && cap
        row(:power, :check, :watts_to_check, cap:)
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
      elsif bike.out_of_class_under?(law)
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

    # Without a speed on record, one to check, as neither the record nor the classes say it's under the cap
    def metric_speed_rule(law, bike)
      cap = law[:kmh]
      kmh = bike.top_kmh
      past = bike.assists_past_kmh
      if (date = law[:limits_start_on])
        row(:speed, :check, :limits_start_on, date:)
      elsif past && cap
        (cap <= past) ? row(:speed, :fail, :speed_past_cap, past:, cap:) : row(:speed, :check, :speed_past, past:, cap:)
      elsif cap.nil?
        row(:speed, :pass, :no_speed_cap)
      elsif kmh.nil?
        row(:speed, :check, :speed_to_check, cap:)
      elsif kmh > cap
        row(:speed, :fail, :speed_over_cap, kmh:, cap:)
      else
        row(:speed, :pass, :speed_within_cap, kmh:)
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
      return row(:throttle, :fail, :throttle_with_class_3_assist) if bike.class_3_throttle_banned?(law)
      return row(:throttle, :check, :throttle_not_stated) if law[:throttle].nil?
      return row(:throttle, :pass, :throttle_allowed) if law[:metric]

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

    conceal :row, :classes_rule, :power_rule, :speed_rule, :metric_speed_rule, :throttle_rule, :throttle_row, :class_3_throttle
  end
end
