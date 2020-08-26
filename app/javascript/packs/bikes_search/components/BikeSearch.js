/* eslint import/no-unresolved: 0 */

import React, { Fragment, Component } from "react";

import Loading from "../../Loading";
import TimeParser from "../../../utils/time_parser.js";
import honeybadger from "../../../utils/honeybadger";

class BikeSearch extends Component {
  // loading states :
  // null before querying
  // true when loading
  // false when query complete

  state = {
    loading: null,
    results: [],
  };

  componentDidMount() {
    this.resultsBeingFetched();
    this.props
      .fetchBikes(this.props.interpretedParams)
      .then(this.resultsFetched)
      .catch(this.handleError);
  }

  componentDidUpdate() {
    if (!window.timeParser) {
      window.timeParser = new TimeParser();
    }
    window.timeParser.localize();
  }

  resultsBeingFetched = () => {
    this.setState({ loading: true });
  };

  resultsFetched = ({ bikes, error }) => {
    const results = bikes || [];
    const loading = !results.length ? null : false;
    this.setState({ results, loading });
    if (error) {
      this.handleError(error);
    }
  };

  handleError = (error) => {
    honeybadger.notify(error, { component: this.props.searchName });
  };

  render() {
    const { serial } = this.props.interpretedParams;

    if (this.state.loading === null) {
      return (
        <div className="row">
          <div className="col-md-12">
            <h3 className="no-exact-results">
              {this.props.t("no_matches_found_html", { serial })}
            </h3>
          </div>
        </div>
      );
    }

    if (this.state.loading) {
      return (
        <div className="row">
          <div className="col-md-12">
            <h3 className="secondary-matches">
              {this.props.t("searching_html", { serial })}
            </h3>
            <Loading />
          </div>
        </div>
      );
    }

    const Result = this.props.resultComponent;
    const stolenness = {
      non: "abandoned",
      all: "all",
      stolen: "stolen",
    }[this.props.interpretedParams.stolenness];

    return (
      <div className="row">
        <div className="col-md-12">
          <h3 className="secondary-matches">
            {this.props.t("matches_found_html", { serial, stolenness })}
          </h3>
          <ul className="bike-boxes">
            {this.state.results.map((bike) => (
              <Result key={bike.id} bike={bike} />
            ))}
          </ul>
        </div>
      </div>
    );
  }
}

export default BikeSearch;
