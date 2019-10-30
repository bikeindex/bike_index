/* eslint import/no-unresolved: 0 */

import React from "react";

import BikeSearch from "./BikeSearch";
import ExternalRegistrySearchResult from "./ExternalRegistrySearchResult";
import { fetchSerialExternalSearch } from "../../api";

class ExternalRegistrySearch extends BikeSearch {
  componentName = "ExternalRegistrySearch";
  fetchBikes = fetchSerialExternalSearch;
  headerDomId = "js-external-registry-search-header";
  resultComponent = ExternalRegistrySearchResult;

  componentWillMount() {
    const { stolenness, query, serial } = this.props.interpretedParams;
    // Only search external registries if looking for
    // stolen/all bikes with no query
    if (stolenness === "non" || query || !serial) { return; }
    super.componentWillMount();
  }
};

export default ExternalRegistrySearch;
