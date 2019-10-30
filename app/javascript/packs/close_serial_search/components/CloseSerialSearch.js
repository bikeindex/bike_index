/* eslint import/no-unresolved: 0 */

import React, { Fragment, Component } from "react";

import CloseSerialSearchResult from "./CloseSerialSearchResult";
import { fetchSerialCloseSearch } from "../../api";
import Loading from "../../Loading";
import honeybadger from "../../utils/honeybadger";
import TimeParser from "../../utils/time_parser";

class CloseSerialSearch extends Component {
  state = {
    loading: false,
    results: []
  }

  componentWillMount() {
    this.resultsBeingFetched();
    fetchSerialCloseSearch(this.props.interpretedParams)
      .then(this.resultsFetched)
      .catch(this.handleError);
  }

  componentDidUpdate() {
    TimeParser().localize();
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
    honeybadger.notify(error, { component: "CloseSerialSearch" });
  }

  toggleHeader = ({ isLoading, resultsCount }) => {
    const header = document.getElementById("js-close-serial-search-header");
    if (!header) { return; }

    header.childNodes.forEach(node => node.classList && node.classList.add("d-none"));

    const titleDisplay = (isLoading)
          ? "loading"
          : (resultsCount)
          ? "loaded"
          : "loaded-none";

    const sectionTitle = header.getElementsByClassName(titleDisplay)[0]
    sectionTitle.classList.remove("d-none");
  }

  render() {
    if (this.state.loading) {
      return <Loading />;
    }

    return (
      <Fragment>
        <ul className="bike-boxes">
          {this.state.results.map(bike => <CloseSerialSearchResult key={bike.id} bike={bike} />)}
        </ul>
      </Fragment>
    );
  }
};

export default CloseSerialSearch;
