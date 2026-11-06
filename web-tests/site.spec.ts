import { test, expect } from '@playwright/test';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const axePath = require.resolve('axe-core/axe.min.js');

test('all sample fixtures diagnose with the source rules and accept pasted text', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await expect(page.locator('#rep')).toContainText('test failure');
  for (const [label, kind] of [
    ['Compiler error', 'compiler error'], ['Linker error', 'linker error'],
    ['Simulator timeout', 'simulator failure'], ['Build timeout', 'timeout'], ['Test failure', 'test failure'],
  ]) {
    await page.getByRole('button', { name: label, exact: true }).click();
    await expect(page.locator('#rep .vd b')).toHaveText(kind);
  }
  await page.getByLabel('Build log', { exact: true }).fill("Sources/App.swift:1:8: error: no such module 'Payments'");
  await expect(page.locator('#rep .vd b')).toHaveText('missing dependency');
  await expect(page.locator('#rep')).toContainText("Sources/App.swift:1:8: error: no such module 'Payments'");
  await page.getByLabel('Build log', { exact: true }).fill('<img src=x onerror="window.injected=true">');
  await expect(page.locator('#rep')).toContainText('<img src=x');
  await expect(page.locator('#rep img')).toHaveCount(0);
  expect(await page.evaluate(() => (window as any).injected)).toBeUndefined();
  expect(errors).toEqual([]);
});

test('keyboard can reach and scroll the quick start and rules', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('#rep')).toContainText('test failure');
  for (const selector of ['#qs', '.tw']) {
    const target = page.locator(selector);
    await target.focus();
    await expect(target).toBeFocused();
    expect(await target.evaluate(el => getComputedStyle(el).outlineStyle)).not.toBe('none');
    const max = await target.evaluate(el => el.scrollWidth - el.clientWidth);
    if (max > 0) {
      await page.keyboard.press('ArrowRight');
      await expect.poll(() => target.evaluate(el => el.scrollLeft)).toBeGreaterThan(0);
    }
  }
});

test('light and dark themes meet automated WCAG AA without page overflow', async ({ page }) => {
  for (const colorScheme of ['light', 'dark'] as const) {
    await page.emulateMedia({ colorScheme, reducedMotion: 'reduce' });
    await page.goto('/');
    await expect(page.locator('#rep')).toContainText('test failure');
    await page.addScriptTag({ path: axePath });
    const violations = await page.evaluate(async () => {
      const result = await (window as any).axe.run(document, { runOnly: ['wcag2a', 'wcag2aa', 'wcag21aa'] });
      return result.violations.map((v: any) => `${v.id}: ${v.nodes.map((n: any) => n.target.join(' ')).join(', ')}`);
    });
    expect(violations).toEqual([]);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  }
});

test('a failed rules request leaves a useful recovery and disabled sample controls', async ({ page }) => {
  await page.route('**/rules.json', route => route.fulfill({ status: 503, body: 'Unavailable' }));
  await page.goto('/');
  await expect(page.locator('#boot')).toContainText('use the CLI commands below');
  await expect(page.locator('#rn')).not.toHaveText('Loading...');
  for (const button of await page.locator('[data-s]').all()) await expect(button).toBeDisabled();
  await expect(page.getByLabel('Build log', { exact: true })).toBeDisabled();
  await expect(page.locator('#qs')).toContainText('swift run buildwatch');
});

test('without JavaScript, the page explains the fallback and keeps CLI commands readable', async ({ browser, baseURL, viewport }) => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport });
  const page = await context.newPage();
  await page.goto(baseURL!);
  await expect(page.locator('#demo-fallback p')).toContainText('browser demo needs JavaScript');
  await expect(page.locator('#demo-fallback a')).toHaveAttribute('href', '#install');
  await expect(page.locator('#qs')).toContainText('swift run buildwatch');
  await expect(page.locator('#smp button').first()).toBeDisabled();
  await expect(page.locator('#boot')).toBeHidden();
  await expect(page.locator('.copy').first()).toBeHidden();
  await context.close();
});

test('reduced motion removes animation and transitions', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  expect(await page.evaluate(() => getComputedStyle(document.documentElement).scrollBehavior)).toBe('auto');
  const moving = await page.evaluate(() => [...document.querySelectorAll('*')].filter(el => {
    const style = getComputedStyle(el);
    return (style.animationName !== 'none' && parseFloat(style.animationDuration) > 0) || parseFloat(style.transitionDuration) > 0;
  }).length);
  expect(moving).toBe(0);
});
