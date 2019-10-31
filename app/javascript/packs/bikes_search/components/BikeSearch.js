/* eslint import/no-unresolved: 0 */

import React, { Fragment, Component } from "react";

import Loading from "../../Loading";
import honeybadger from "../../utils/honeybadger";
import TimeParser from "../../utils/time_parser";


class BikeSearch extends Component {
  // loading states :
  // null before querying
  // true when loading
  // false when query complete

  state = {
    loading: null,
    results: []
  }

  componentDidMount() {
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
  }

  resultsFetched = ({ bikes, error }) => {
    this.setState({ results: bikes || [], loading: false });
    if (error) { this.handleError(error) }
  }

  handleError = error => {
    honeybadger.notify(error, { component: this.props.searchName });
  }

  render() {
    const stolenness = {
      "non": "abandoned",
      "all": "all",
      "stolen": "stolen",
    }[this.props.interpretedParams.stolenness];
    const { serial } = this.props.interpretedParams;

    if (this.state.loading === null) {
      return <div className="row">
               <div className="col-md-12">
                 <h3 className="secondary-matches">
                   {this.props.t("no_matches_found_html", { serial })}
                 </h3>
               </div>
             </div>

    }

    if (this.state.loading) {
      return <div className="row">
               <div className="col-md-12">
                 <h3 className="secondary-matches">
                   {this.props.t("searching_html", { serial })}
                 </h3>
                 <Loading />;
               </div>
             </div>
    }

    const Result = this.props.resultComponent;
    return (
      <div className="row">
        <div className="col-md-12">
          <h3 className="secondary-matches">
            {this.props.t("matches_found_html", { serial, stolenness })}
          </h3>
          <ul className="bike-boxes">
            {this.state.results.map(bike => <Result key={bike.id} bike={bike}/>)}
          </ul>
        </div>
      </div>
    )
  }
};

export default BikeSearch;
