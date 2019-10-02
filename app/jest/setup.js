/* eslint import/no-extraneous-dependencies: 0 */

import $ from 'jquery';
import { configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';

configure({ adapter: new Adapter() });

global.$ = global.jQuery = $;
