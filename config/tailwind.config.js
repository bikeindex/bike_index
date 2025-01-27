const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  prefix: 'tw-',
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
    './app/components/**/*.{erb,haml,html,rb}'
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        'blue': {
          // '50': '#f9f5ff',
          // '100': '#f1e7ff',
          // '200': '#e6d4ff',
          // '300': '#d2b2ff', // rgb(210, 178, 255)
          // '400': '#b780ff',
          '500': '#3498db',
          // '600': '#842df0',
          // '700': '#701cd4',
          // '800': '#601dac',
          '900': '#2c3e50',
          '950': '#1D2834', // rgb(52, 4, 103)
        }
      },
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries')
    // require('flowbite/plugin') // not sure this is necessary after copying!
  ]
}
