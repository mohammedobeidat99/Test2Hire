/** @type {import('next').NextConfig} */
const isProd = process.env.NODE_ENV === 'production';

const nextConfig = {
  ...(isProd ? { output: 'export' } : {}),
  serverExternalPackages: ['@grpc/grpc-js', 'firebase-admin'],
  reactStrictMode: false,
  images: {
    unoptimized: true,
  },
};

module.exports = nextConfig;
