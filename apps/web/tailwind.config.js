/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        wild: {
          bg: "#0d1117",
          panel: "#161b22",
          accent: "#2ea043",
          gold: "#d29922",
          border: "#30363d",
        },
      },
    },
  },
  plugins: [],
};
