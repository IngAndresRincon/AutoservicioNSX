import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// El build se sirve como estático desde Express en /public/app
export default defineConfig({
  plugins: [react()],
  base: '/public/app/',
  build: {
    outDir: '../src/public/app',
    emptyOutDir: true,
  },
  server: {
    proxy: {
      '/api': 'http://localhost:5001',
    },
  },
});
