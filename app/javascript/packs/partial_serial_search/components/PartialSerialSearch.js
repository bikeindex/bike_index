/* eslint import/no-unresolved: 0 */

import React, { Fragment, Component } from "react";

import PartialSerialSearchResult from "./PartialSerialSearchResult";
import { fetchSerialPartialSearch } from "../../api";
import Loading from "../../Loading";
import honeybadger from "../../utils/honeybadger";

class PartialSerialSearch extends Component {
  state = {
    loading: false,
    results: []
  }

  componentWillMount() {
    this.resultsBeingFetched();
    fetchSerialPartialSearch(this.props.interpretedParams)
      .then(this.resultsFetched)
      .catch(this.handleError);
  }

  resultsBeingFetched = () => {
    this.setState({ loading: true });
    this.toggleHeader({ isLoading: true });
  }

  resultsFetched = response => {
    this.setState({ results: response.bikes || [], loading: false });
    this.toggleHeader({ isLoading: false, resultsCount: this.state.results.length });
  }

  handleError = error => {
    honeybadger.notify(error, { component: "PartialSerialSearch" });
  }

  toggleHeader = ({ isLoading, resultsCount }) => {
    const header = document.getElementById("js-partial-serial-search-header");
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
          {this.state.results.map(bike => <PartialSerialSearchResult key={bike.id} bike={bike} />)}
        </ul>
      </Fragment>
    );
  }
};

export default PartialSerialSearch;
