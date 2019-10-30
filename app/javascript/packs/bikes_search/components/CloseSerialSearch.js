/* eslint import/no-unresolved: 0 */

import React from "react";

import BikeSearch from "./BikeSearch";
import { fetchSerialCloseSearch } from "../../api";

class CloseSerialSearch extends BikeSearch {
  componentName = "CloseSerialSearch";
  fetchBikes = fetchSerialCloseSearch;
  headerDomId = "js-close-serial-search-header";
};

export default CloseSerialSearch;
