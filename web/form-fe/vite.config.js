import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  envPrefix: ['VITE_', 'GEMINI_'],
  server: {
    proxy: {
      '/api': {
        target: 'https://api.formup.my.id',
        changeOrigin: true,
        secure: false,
      },
      '/questions': {
        target: 'https://api.formup.my.id',
        changeOrigin: true,
        secure: false,
      },
      '/uploads': {
        target: 'https://api.formup.my.id',
        changeOrigin: true,
        secure: false,
      },
      '/banners': {
        target: 'https://api.formup.my.id',
        changeOrigin: true,
        secure: false,
      },
    },
  },
})
