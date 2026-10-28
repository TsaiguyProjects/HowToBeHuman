/// <reference types="vite/client" />
/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'build',
    emptyOutDir: true,
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./tests/setupTests.ts'],
    // Playwright specs live in tests/e2e and must not run under Vitest
    include: ['tests/unit/**/*.test.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['src/vite-env.d.ts'],
      // Coverage gate: `pnpm coverage` and CI fail below these thresholds.
      thresholds: {
        lines: 95,
        functions: 95,
        branches: 95,
        statements: 95,
      },
    },
  },
})
