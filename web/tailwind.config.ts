import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#FFCE00", // «Детское такси» yellow
          dark: "#F5B800",
          soft: "#FFF6D6",
        },
        ink: "#15161A",
        muted: "#8A8F98",
        line: "#ECEEF1",
      },
      fontFamily: {
        sans: ["var(--font-manrope)", "system-ui", "sans-serif"],
      },
      borderRadius: {
        xl2: "1.25rem",
      },
      boxShadow: {
        soft: "0 8px 24px rgba(0,0,0,0.05)",
      },
    },
  },
  plugins: [],
};

export default config;
