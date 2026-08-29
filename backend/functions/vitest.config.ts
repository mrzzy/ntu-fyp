import { defineConfig } from "vitest/config";
import { loadEnv } from "vite";

export default defineConfig(({ mode }) => ({
  test: {
    environment: "node",
    globals: true,
    // load all vars from .env so tests can access secrets
    env: loadEnv(mode, process.cwd(), ""),
  },
}));
