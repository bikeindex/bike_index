
import React from 'react';
import { shallow} from 'enzyme';
import toJson from 'enzyme-to-json';
import MultiSerialSearch from './MultiSerialSearch';

describe('<MultiSerialSearch /> shallow rendered', () => {
  it('matches the snapshot', () => {
    const tree = shallow(<MultiSerialSearch />);
    expect(toJson(tree)).toMatchSnapshot();
  });
});