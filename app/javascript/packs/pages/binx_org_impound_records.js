import log from "../utils/log";

export default class BinxAppOrgImpoundRecords {
  constructor() {
    this.indexView =
      document.getElementsByTagName("body")[0].id ===
      "organized_impound_records_index";
  }
  init() {
    if (this.indexView) {
      this.initializeIndex();
    }
  }

  initializeIndex() {
    // Call the existing coffeescript class that manages the bike searchbar
    new BikeIndex.BikeSearchBar();
  }
}
