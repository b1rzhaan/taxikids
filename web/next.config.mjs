/** @type {import('next').NextConfig} */
const nextConfig = {
  // Leaflet (react-leaflet) падает при двойном монтировании StrictMode в dev.
  reactStrictMode: false,
};

export default nextConfig;
