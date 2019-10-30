/* eslint import/no-unresolved: 0 */

import React, { Fragment, Component } from "react";

import BikeSearchResult from "./BikeSearchResult";
import api from "../../api";
import Loading from "../../Loading";
import honeybadger from "../../utils/honeybadger";
import TimeParser from "../../utils/time_parser";

class BikeSearch extends Component {
  state = {
    loading: false,
    results: []
  }

  componentWillMount() {
    this.resultsBeingFetched();
    this.props.fetchBikes(this.props.interpretedParams)
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
    honeybadger.notify(error, { component: this.props.searchName });
  }

  toggleHeader = ({ isLoading, resultsCount }) => {
    const header = document.getElementById(this.props.headerDomId);
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
    const Result = this.props.resultComponent || BikeSearchResult;

    if (this.state.loading) {
      return <Loading />;
    }

    return (
      <Fragment>
        <ul className="bike-boxes">
          {this.state.results.map(bike => <Result key={bike.id} bike={bike}/>)}
        </ul>
      </Fragment>
    );
  }
};

export default BikeSearch;
