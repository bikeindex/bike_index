import selectize from "selectize";

// Right now we're using selectize.js (https://selectize.github.io/selectize.js/) to make our select boxes fancy.
// This could be changed to some other library at some point - this makes it possible for us to abstract that away.
// Just add the `unfancy` and `fancy-select` classes to a select box and it will be a fancy select box!
const LoadFancySelects = () => {
  $(".unfancy.fancy-select.no-restore-on-backspace select").selectize({
    create: false,
    plugins: []
  });
  // Remove, because we've already added them
  $(".unfancy.fancy-select.no-restore-on-backspace").removeClass("unfancy");

  $(".unfancy.fancy-select select").selectize({
    create: false,
    plugins: ["restore_on_backspace"]
  });
  // Remove them so we don't initialize twice
  $(".unfancy.fancy-select").removeClass("unfancy");
};

export default LoadFancySelects;
