import { defineConfig } from "vitest/config"

export default defineConfig({
  test: {
    // リポジトリ全体を走査すると tmp/ や vendor/ まで見に行くため、TSを置く場所に限定する
    include: ["app/javascript/**/*.test.{ts,tsx}"],
    environment: "jsdom",
    setupFiles: ["app/javascript/test-setup.ts"]
  }
})
