import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './web-tests',
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 2,
  timeout: 45_000,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: { baseURL: 'http://127.0.0.1:4178', screenshot: 'only-on-failure', trace: 'retain-on-failure' },
  projects: ['chromium', 'firefox', 'webkit'].flatMap(browserName =>
    [375, 1440].map(width => ({
      name: `${browserName}-${width}`,
      use: { browserName: browserName as 'chromium' | 'firefox' | 'webkit', viewport: { width, height: 900 } },
    })),
  ),
  webServer: { command: 'node scripts/serve-site.mjs', url: 'http://127.0.0.1:4178', reuseExistingServer: false },
});
