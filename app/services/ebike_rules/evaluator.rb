# frozen_string_literal: true

module EbikeRules
  # Checks a bike against a state's law, one row per rule. Each row's status is :pass, :check
  # (legal, with a rule for the rider to follow), :fail or :info, and its note is a symbol
  # naming what the rule means for this bike, with the values that note needs in args
  module Evaluator
    extend Functionable

    def rules(law:, bike:)
      e_bike_class = bike.e_bike_class
      [
        classes_rule(law, e_bike_class),
        power_rule(law, bike.watts),
        speed_rule(law, bike, e_bike_class),
        throttle_rule(bike.throttle, e_bike_class),
        # how to ride a legal e-bike, which a bike with no class isn't
        *([age_rule(law, e_bike_class), helmet_rule(law, e_bike_class), paths_rule(law, e_bike_class)] if e_bike_class),
        row(:label, :info, :keep_label)
      ]
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

    def classes_rule(law, e_bike_class)
      if e_bike_class.nil?
        row(:classes, :fail, :not_classified)
      elsif law[:classes].include?(e_bike_class)
        row(:classes, :pass, :class_recognized, e_bike_class:)
      else
        row(:classes, :fail, :class_not_recognized, e_bike_class:)
      end
    end

    def power_rule(law, watts)
      cap = law[:watt_cap]
      if watts.nil?
        row(:power, :info, :watts_not_provided)
      elsif watts > cap
        row(:power, :fail, :watts_over_cap, watts:, cap:)
      else
        row(:power, :pass, :watts_within_cap, watts:)
      end
    end

    # A bike with no class is held to the fastest class's limit
    def speed_rule(law, bike, e_bike_class)
      mph = bike.top_assist_mph
      cap = law[:speed][e_bike_class] || law[:speed].values.max
      if mph.nil?
        row(:speed, :info, :speed_not_provided)
      elsif mph <= cap
        row(:speed, :pass, :speed_within_cap, mph:)
      elsif e_bike_class
        row(:speed, :fail, :speed_over_class_cap, mph:, cap:, e_bike_class:)
      else
        row(:speed, :fail, :speed_over_cap, mph:, cap:)
      end
    end

    def throttle_rule(throttle, e_bike_class)
      return row(:throttle, :pass, :no_throttle) unless throttle

      case e_bike_class
      when 1 then row(:throttle, :fail, :class_1_throttle)
      when 2 then row(:throttle, :pass, :throttle_allowed)
      when 3 then row(:throttle, :check, :class_3_throttle)
      else row(:throttle, :info, :has_throttle)
      end
    end

    def age_rule(law, e_bike_class)
      age = law[:age_min][e_bike_class]
      if age
        row(:age, :check, :minimum_age, age:)
      else
        row(:age, :pass, :no_minimum_age, e_bike_class:)
      end
    end

    def helmet_rule(law, e_bike_class)
      if law[:helmet_all].include?(e_bike_class)
        row(:helmet, :check, :helmet_required)
      elsif law[:helmet_minor].include?(e_bike_class)
        row(:helmet, :info, :helmet_minors)
      else
        row(:helmet, :pass, :helmet_not_required, e_bike_class:)
      end
    end

    def paths_rule(law, e_bike_class)
      if law[:paths_restricted].include?(e_bike_class)
        row(:paths, :check, :paths_restricted)
      else
        row(:paths, :pass, :paths_allowed)
      end
    end

    conceal :row, :classes_rule, :power_rule, :speed_rule, :throttle_rule, :age_rule, :helmet_rule, :paths_rule
  end
end
