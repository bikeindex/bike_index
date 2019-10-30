/* eslint import/no-unresolved: 0 */

import React from "react";

import BikeSearch from "./BikeSearch";
import { fetchPartialMatchSearch } from "../../api";

class PartialSerialSearch extends BikeSearch {
  componentName = "PartialSerialSearch";
  fetchBikes = fetchPartialMatchSearch;
  headerDomId = "js-partial-serial-search-header";
};

export default PartialSerialSearch;
