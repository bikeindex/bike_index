function BinxAdminInvoices() {
  return {
    init() {
      this.updateInvoiceCalculations();
      $(".inputTriggerRecalculation").on("change paste keyup", e =>
        this.updateInvoiceCalculations()
      );
      $("#invoiceForm .paidFeatureCheck input").on("change", e =>
        this.updateInvoiceCalculations()
      );
    },

    updateInvoiceCalculations() {
      let oneTimeCost, recurringCost;
      const recurring = $(".paidFeatureCheck input.recurring:checked")
        .get()
        .map(i => parseInt($(i).attr("data-amount"), 10));
      if (recurring.length > 0) {
        recurringCost = recurring.reduce((x, y) => x + y);
      } else {
        recurringCost = 0;
      }
      const oneTime = $(".paidFeatureCheck input.oneTime:checked")
        .get()
        .map(i => parseInt($(i).attr("data-amount"), 10));
      if (oneTime.length > 0) {
        oneTimeCost = oneTime.reduce((x, y) => x + y);
      } else {
        oneTimeCost = 0;
      }
      $("#recurringCount").text(recurring.length);
      $("#oneTimeCount").text(oneTime.length);
      $("#recurringCost").text(`${recurringCost}.00`);
      $("#oneTimeCost").text(`${oneTimeCost}.00`);
      $("#totalCost").text(`${recurringCost + oneTimeCost}.00`);
      const due = parseInt($("#invoice_amount_due").val(), 10);
      $("#discountCost").text(`${-1 * (recurringCost + oneTimeCost - due)}.00`);

      const checked_ids = $(".paidFeatureCheck input:checked")
        .get()
        .map(i => $(i).attr("data-id"));
      $("#invoice_paid_feature_ids").val(checked_ids);
    }
  };
}

export default BinxAdminInvoices;
