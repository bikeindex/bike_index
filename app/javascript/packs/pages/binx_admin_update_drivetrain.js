function BinxAdminUpdateDrivetrain() {
  return {
    init() {
      this.initializeEventListeners();
      // for (let side of ["front", "rear"]) {
      //   this.initializeWheelDiams(side);
      // }
      this.setInitialGears();
    },

    initializeEventListeners() {
      $(".standard-diams select").change(e => {
        return this.updateDiamsFromStandardChange(e);
      });
      $(".drive-check").change(e => {
        return this.toggleDrivetrainChecks(e);
      });
      return $("#edit_drivetrain select").change(e => {
        return this.updateDrivetrainValue(e);
      });
    },

    //
    // Wheels
    updateDiamsFromStandardChange(e) {
      const current_val = e.target.value;
      const $target = $(e.target)
        .parents(".form-well-input")
        .find(".all-diams select");
      const { selectize } = $target.selectize()[0];
      return selectize.setValue(current_val);
    },

    // initializeWheelDiams(side) {
    //   const current_val = $("#bike_"  + side + "_wheel_size_id").val();
    //   const $standard_diams = $(`#bike_${side}_standard select`);
    //
    //   if (current_val.length > 0) {
    //     // Seems like you can't do normal options mapping because selectize,
    //     // so we have to do it through selectize
    //     const { selectize } = $standard_diams.selectize()[0];
    //     const standard_values = Object.keys(selectize.options);
    //     if (Array.from(standard_values).includes(current_val)) {
    //       return selectize.setValue(current_val);
    //     } else {
    //       const $all_diams_btn = $standard_diams
    //         .parents(".related-fields")
    //         .find(".show-all-diams");
    //       return $all_diams_btn.trigger("click", false);
    //     }
    //   }
    // },

    //
    // Drivetrain
    toggleDrivetrainChecks(e) {
      const $target = $(e.target);
      const id = $target.attr("id");
      if (id === "fixed_gear_check") {
        return this.toggleFixed($target.prop("checked"));
      } else {
        if (id === "front_gear_select_internal") {
          this.setDrivetrainValue("front_gear_select");
        }
        if (id === "rear_gear_select_internal") {
          return this.setDrivetrainValue("rear_gear_select");
        }
      }
    },

    toggleFixed(is_fixed) {
      const fixed_values = {};
      for (let side of ["front", "rear"]) {
        // Remove the select gear value
        const selectize = $(`#${side}_gear_select`).selectize()[0];
        selectize.selectize.setValue("");
        // Set the fixed values
        fixed_values[side] = $(`#${side}_gear_select_value`).attr("data-fixed");
      }
      if (is_fixed) {
        return $("#edit_drivetrain .not-fixed").slideUp("medium", function() {
          $('#edit_drivetrain .not-fixed input[type="checkbox"]').prop(
            "checked",
            ""
          );
          $(
            `#front_gear_select_value #bike_front_gear_type_id_${
              fixed_values.front
            }`
          ).prop("checked", true);
          return $(
            `#rear_gear_select_value #bike_rear_gear_type_id_${
              fixed_values.rear
            }`
          ).prop("checked", true);
        });
      } else {
        $(
          "#front_gear_select_value .no-gear-selected, #rear_gear_select_value .no-gear-selected"
        ).prop("checked", true);
        return $(".not-fixed").slideDown();
      }
    },

    setDrivetrainValue(position) {
      const v = parseInt($(`#${position}`).val(), 10);
      const i = $(`#${position}_internal`).prop("checked");
      if (isNaN(v)) {
        return $(`#${position}_value .placeholder`).prop(
          "selected",
          "selected"
        );
      } else {
        $(`#${position}_value .count_${v}.internal_${i}`).prop("checked", true);
        if (v === 0) {
          return $("#rear_gear_select_internal").prop("checked", true);
        }
      }
    },

    updateDrivetrainValue(event) {
      if ($("#fixed_gear_check").prop("checked")) {
        return true;
      } else {
        const position = $(event.target).attr("id");
        return this.setDrivetrainValue(position);
      }
    },

    setInitialGears() {
      if ($("#fixed_gear_check").prop("checked") === true) {
        return this.toggleFixed(true);
      } else {
        return (() => {
          const result = [];
          for (let side of ["front", "rear"]) {
            const count = $(`#${side}_gear_select_value`).attr(
              "data-initialcount"
            );
            if (!isNaN(count)) {
              const selectize = $(`#${side}_gear_select`).selectize()[0];
              result.push(selectize.selectize.setValue(count));
            } else {
              result.push(undefined);
            }
          }
          return result;
        })();
      }
    }
  };
}
export default BinxAdminUpdateDrivetrain;
