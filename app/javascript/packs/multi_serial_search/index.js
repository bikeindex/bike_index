import React from 'react';
import ReactDOM from 'react-dom';
import MultiSerialSearch from './components/MultiSerialSearch';

document.addEventListener('DOMContentLoaded', () => {
  const el = document.getElementById('multiserial-search');

  ReactDOM.render(
    <MultiSerialSearch />,
    el,
  );
});
