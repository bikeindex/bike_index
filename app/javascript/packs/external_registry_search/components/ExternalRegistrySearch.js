/* eslint import/no-unresolved: 0 */

import React, { Fragment, Component } from "react";

import ExternalRegistrySearchResult from "./ExternalRegistrySearchResult";
import { fetchSerialExternalSearch } from "../../api";
import Loading from "../../Loading";
import honeybadger from "../../utils/honeybadger";

class ExternalRegistrySearch extends Component {
  state = {
    loading: false,
    results: []
  }

  componentWillMount() {
    const { stolenness, query, serial } = this.props;
    // Only search external registries if looking for
    // stolen/all bikes with no query
    if (stolenness === "non" || query) { return; }

    this.resultsBeingFetched();

    fetchSerialExternalSearch(serial)
      .then(this.resultsFetched)
      .catch(this.handleError);
  }

  resultsBeingFetched = () => {
    this.setState({ loading: true });
    this.toggleHeader({ isLoading: true });
  }

  resultsFetched = ({ bikes, error }) => {
    this.setState({ results: bikes || [], loading: false });
    this.toggleHeader({ isLoading: false, resultsCount: this.state.results.length });
    if (error) { this.handleError(error) }
  }

  handleError = error => {
    honeybadger.notify(error, { component: "MultiSerialSearch" });
  }

  toggleHeader = ({ isLoading, resultsCount }) => {
    const header = document.getElementById("js-external-registry-search-header");
    if (!header) { return; }

    header.childNodes.forEach(node => node.classList && node.classList.add("d-none"));

    const titleDisplay = (isLoading)
          ? "loading"
          : (resultsCount)
          ? "loaded"
          : "loaded-none";

    const sectionTitle = header.getElementsByClassName(titleDisplay)[0];
    sectionTitle.classList.remove("d-none");
  }

  render() {
    if (this.state.loading) {
      return <Loading />;
    }

    return (
      <Fragment>
        <ul className="bike-boxes">
          {this.state.results.map(bike => <ExternalRegistrySearchResult key={bike.id} bike={bike}/>)}
        </ul>
      </Fragment>
    );
  }
};

export default ExternalRegistrySearch;
