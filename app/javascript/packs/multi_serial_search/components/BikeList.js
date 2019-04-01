import React from 'react';
import PropTypes from 'prop-types';
import pluralize from 'pluralize';

const BikeList = ({ bikes, serial, fuzzySearching }) => {
  const resultsTitle = bikes.length > 19 ? 'First 20 of many' : bikes.length;

  return (
    <div className={fuzzySearching && 'multiserial-fuzzy-result'}>
      <h3>
        {fuzzySearching && 'Close to serial '}
        <span className="serial-text">{serial} - </span>
        {resultsTitle} {pluralize('results', bikes.length)}
      </h3>
      <ul>
        {bikes.map(({
          stolen, url, id, title,
        }) => (
          <li key={id}>
            {stolen && <span className="stolen-color">Stolen</span>}
            {' '}
            <a href={url} target="_blank" rel="noopener noreferrer">
              {title}
            </a>
            <span className="serial-text">{serial}</span>
          </li>
        ))}
      </ul>
    </div>
  );
};

BikeList.propTypes = {
  bikes: PropTypes.arrayOf(PropTypes.object),
  fuzzySearching: PropTypes.bool,
  serial: PropTypes.string,
};

export default BikeList;
