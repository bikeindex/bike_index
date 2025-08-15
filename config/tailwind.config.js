module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html}',
    './app/components/**/*.{erb,haml,html,rb}'
  ],
  darkMode: 'selector',
  theme: {
    extend: {
      colors: {
        blue: {
          50: '#f2f8fd',
          100: '#e3effb',
          200: '#c1dff6',
          300: '#8ac5ef',
          400: '#4ca7e4',
          500: '#3498db', // OG Bike Index blue
          600: '#176fb2',
          700: '#145990',
          800: '#144c78',
          900: '#164064',
          950: '#0f2942'
        },
        green: {
          50: '#f1fcf5',
          100: '#defaea',
          200: '#bef4d4',
          300: '#8beab3',
          400: '#52d689',
          500: '#2ecc71', // OG Bike Index green
          600: '#1d9c53',
          700: '#1b7a43',
          800: '#1a6139',
          900: '#175031',
          950: '#072c18'
        },
        red: {
          50: '#fef3f2',
          100: '#fde5e3',
          200: '#fcd0cc',
          300: '#f9b0a8',
          400: '#f38276',
          500: '#e74c3c', // OG Bike Index red
          600: '#d53d2d',
          700: '#b33022',
          800: '#942b20',
          900: '#7b2921',
          950: '#43110c'
        },
        slate: { // slate is pretty close to blue, but -- I still like it!
          50: '#f5f7fa',
          100: '#eaeff4',
          200: '#cfdce8',
          300: '#a6bfd3',
          400: '#759cbb',
          500: '#5480a3',
          600: '#416788',
          700: '#35526f',
          800: '#2f475d',
          900: '#2c3e50', // OG Bike Index blue-dark
          950: '#1d2834'
        }
      }
    }
  }
  // plugins: [
  //   require('@tailwindcss/forms'),
  //   // require('flowbite/plugin') // not sure this is necessary after copying!
  // ]
}
