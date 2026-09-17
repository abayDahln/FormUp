# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: tests/full.spec.js >> FormUp - detailed public respondent flow >> captures and displays a server error when submitting a form fails
- Location: tests/full.spec.js:399:3

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: getByText('Playwright Error Handling Form')
Expected: visible
Error: strict mode violation: getByText('Playwright Error Handling Form') resolved to 2 elements:
    1) <span class="truncate mr-3">Playwright Error Handling Form — 0 dari 1 soal te…</span> aka getByText('Playwright Error Handling Form — 0 dari 1 soal terjawab')
    2) <h1 class="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight break-words">Playwright Error Handling Form</h1> aka getByRole('heading', { name: 'Playwright Error Handling Form' })

Call log:
  - Expect "toBeVisible" getByText('Playwright Error Handling Form') with timeout 5000ms
  - waiting for getByText('Playwright Error Handling Form')

```

# Page snapshot

```yaml
- generic [ref=e3]:
  - generic [ref=e5]:
    - generic [ref=e6]: Playwright Error Handling Form — 0 dari 1 soal terjawab
    - generic [ref=e7]: 0%
  - generic [ref=e9]:
    - generic [ref=e11]:
      - button "Mode Gelap" [ref=e12] [cursor=pointer]
      - button "Laporkan Masalah" [ref=e16] [cursor=pointer]
    - generic [ref=e21]:
      - heading "Playwright Error Handling Form" [level=1] [ref=e23]
      - generic [ref=e24]:
        - generic [ref=e25]: "Nama Anda (Opsional):"
        - textbox "Masukkan nama lengkap Anda..." [ref=e26]
    - generic [ref=e27]:
      - generic [ref=e28]:
        - generic [ref=e29]: "1"
        - paragraph [ref=e34]: Describe your answer
        - textbox "Ketikkan jawaban Anda di sini..." [ref=e36]
      - button "Kirim Respons Formulir" [ref=e38] [cursor=pointer]
```

# Test source

```ts
  335 |       await clickIfVisible(page.getByRole('button', { name: /tambah soal|tambah pertanyaan/i }));
  336 |       await clickIfVisible(page.getByTitle('Toggle Live Preview'));
  337 |       await clickIfVisible(page.getByTitle('Panduan Form Builder'));
  338 |       await clickIfVisible(page.getByRole('button', { name: /generate soal ai/i }));
  339 |       const aiTopic = page.getByPlaceholder(/contoh: kuis ujian akhir/i);
  340 |       if (await aiTopic.isVisible().catch(() => false)) {
  341 |         await aiTopic.fill('Dry-run materi matematika');
  342 |         await clickIfVisible(page.getByText('Rumus (KaTeX)', { exact: true }));
  343 |         await clickIfVisible(page.getByText('Code Block', { exact: true }));
  344 |         await clickIfVisible(page.getByText(/Opsi Tambahan/i));
  345 |         await fillIfVisible(page, page.getByPlaceholder(/tempel teks materi/i), 'Materi dry-run');
  346 |         await clickIfVisible(page.getByRole('button', { name: /tutup|batal|cancel/i }));
  347 |       }
  348 |       await clickIfVisible(page.getByRole('button', { name: /impor|import/i }));
  349 |       await expect(page.locator('body')).toContainText(/import|impor|pertanyaan/i);
  350 |       await clickIfVisible(page.getByTitle('Tutup'));
  351 |       await clickIfVisible(page.getByTitle('Menu Tindakan Cepat'));
  352 |       await clickIfVisible(page.getByRole('button', { name: /revisi massal ai/i }));
  353 |       await fillIfVisible(page, page.getByPlaceholder(/instruksi revisi untuk semua soal/i), 'Dry-run revisi');
  354 |       await clickIfVisible(page.getByRole('button', { name: /selesai pilih|revisi massal ai/i }));
  355 |       await clickIfVisible(page.getByRole('button', { name: /undo/i }));
  356 |       await clickIfVisible(page.getByRole('button', { name: /redo/i }));
  357 |       await clickIfVisible(page.getByRole('button', { name: /export soal \(csv\)/i }));
  358 | 
  359 |       await gotoApp(page, `/forms/${formId}/responses`);
  360 |       await expect(page.locator('body')).toContainText(/Respons|Memuat respons|Daftar Respons/i);
  361 |       await clickIfVisible(page.getByRole('button', { name: /monitoring/i }));
  362 |       await clickIfVisible(page.getByRole('button', { name: /laporan|masukan|feedback/i }));
  363 |       await clickIfVisible(page.getByTitle('Segarkan Data Monitoring'));
  364 |       await clickIfVisible(page.getByPlaceholder(/cari nama responden/i));
  365 |       await clickIfVisible(page.getByTitle('Unduh format CSV'));
  366 |       await clickIfVisible(page.getByTitle('Unduh format Excel (.xlsx)'));
  367 |       await clickIfVisible(page.getByTitle('Unduh format PDF (.pdf)'));
  368 | 
  369 |       await gotoApp(page, `/forms/${formId}/analytics`);
  370 |       await expect(page.locator('body')).toContainText(/Analisis|Memuat analisis|Diagram/i);
  371 |       await page.locator('select[aria-label="Model Analisis Pintar"]').selectOption({ index: 0 }).catch(() => {});
  372 |       await clickIfVisible(page.getByTitle('Export ke Excel (.xlsx)'));
  373 |       await clickIfVisible(page.getByTitle('Export ke CSV (.csv)'));
  374 |       await clickIfVisible(page.getByTitle('Export ke PDF (.pdf)'));
  375 |     }
  376 | 
  377 |     await gotoApp(page, '/admin');
  378 |     if (!(await page.getByText(/akses ditolak|khusus admin|tidak memiliki akses/i).first().isVisible().catch(() => false))) {
  379 |       const adminSearch = page.getByPlaceholder('Cari data...');
  380 |       if (await adminSearch.isVisible().catch(() => false)) await adminSearch.fill('test');
  381 |       await clickIfVisible(page.getByRole('button', { name: /pengguna|users/i }));
  382 |       await clickIfVisible(page.getByRole('button', { name: /formulir|forms/i }));
  383 |       await clickIfVisible(page.getByRole('button', { name: /umpan balik|feedback/i }));
  384 |     }
  385 |     await assertNoReactCrash(page);
  386 | 
  387 |     // Auth lifecycle: logout memang diuji di akhir setelah seluruh fitur selesai.
  388 |     await gotoApp(page, '/dashboard');
  389 |     await clickIfVisible(page.getByRole('button', { name: /keluar/i }));
  390 |     const logoutConfirm = page.getByRole('button', { name: /ya, lanjutkan|keluar/i }).last();
  391 |     if (await logoutConfirm.isVisible().catch(() => false)) await logoutConfirm.click();
  392 |     await expect(page).toHaveURL(/\/login/);
  393 |     await login(page);
  394 |     await expect(page).toHaveURL(/\/dashboard/);
  395 |   });
  396 | });
  397 | 
  398 | test.describe('FormUp - detailed public respondent flow', () => {
  399 |   test('captures and displays a server error when submitting a form fails', async ({ page }) => {
  400 |     const errorLink = 'playwright-error-submit-form';
  401 |     const problems = observeRuntimeErrors(page);
  402 |     await page.route(`**/api/public/forms/${errorLink}`, async (route) => {
  403 |       await route.fulfill({
  404 |         status: 200,
  405 |         contentType: 'application/json',
  406 |         body: JSON.stringify({
  407 |           data: {
  408 |             id: 99001,
  409 |             title: 'Playwright Error Handling Form',
  410 |             formLink: errorLink,
  411 |             formTypeId: 1,
  412 |             requiresToken: false,
  413 |             oneResponse: false,
  414 |             showScore: false,
  415 |           },
  416 |         }),
  417 |       });
  418 |     });
  419 |     await page.route(`**/api/public/forms/${errorLink}/questions`, async (route) => {
  420 |       await route.fulfill({
  421 |         status: 200,
  422 |         contentType: 'application/json',
  423 |         body: JSON.stringify({ data: [{ id: 990011, typeId: 1, question: '<p>Describe your answer</p>', isRequired: false }] }),
  424 |       });
  425 |     });
  426 |     await page.route(`**/api/public/forms/${errorLink}/responses`, async (route) => {
  427 |       await route.fulfill({
  428 |         status: 500,
  429 |         contentType: 'application/json',
  430 |         body: JSON.stringify({ message: 'Simulated submit failure' }),
  431 |       });
  432 |     });
  433 | 
  434 |     await gotoApp(page, `/f/${errorLink}`);
> 435 |     await expect(page.getByText('Playwright Error Handling Form')).toBeVisible();
      |                                                                    ^ Error: expect(locator).toBeVisible() failed
  436 |     await page.getByPlaceholder(/masukkan nama lengkap/i).fill('Error Test Respondent');
  437 |     await page.getByPlaceholder(/ketikkan jawaban/i).fill('This answer is only for the error test.');
  438 |     await page.getByRole('button', { name: /kirim formulir/i }).click();
  439 |     await expect(page.locator('body')).toContainText(/Simulated submit failure|Gagal mengirimkan respons formulir/i);
  440 |     assertExpectedApiFailure(problems);
  441 |   });
  442 | 
  443 |   test('form runner supports respondent identity, theme, navigation, reporting, and validation', async ({ page }) => {
  444 |     await gotoApp(page, `/f/${formLink}`);
  445 |     await expect(page).toHaveURL(new RegExp(`/f/${formLink}`));
  446 |     const accessToken = page.getByPlaceholder('Masukkan token sandi...');
  447 |     if (await accessToken.isVisible().catch(() => false)) {
  448 |       await accessToken.fill('invalid-dry-run-token');
  449 |       await page.getByRole('button', { name: /buka formulir/i }).click();
  450 |       await expect(page.locator('body')).toContainText(/sandi|token|gagal|tidak tersedia/i);
  451 |       return;
  452 |     }
  453 |     const name = page.getByPlaceholder(/masukkan nama lengkap/i);
  454 |     if (!(await name.isVisible().catch(() => false))) {
  455 |       await expect(page.locator('body')).toContainText(/tidak tersedia|memuat|sandi|formulir/i);
  456 |       return;
  457 |     }
  458 |     await name.fill('Playwright Respondent');
  459 |     await clickIfVisible(page.getByRole('button', { name: /mode gelap/i }));
  460 |     await clickIfVisible(page.getByRole('button', { name: /navigasi soal cepat/i }));
  461 |     await clickIfVisible(page.getByRole('button', { name: /laporkan masalah/i }));
  462 |     const report = page.getByPlaceholder(/ceritakan detail kendala/i);
  463 |     if (await report.isVisible().catch(() => false)) {
  464 |       const reportErrors = observeRuntimeErrors(page);
  465 |       await page.route('**/api/forms/*/feedback', async (route) => {
  466 |         await route.fulfill({
  467 |           status: 500,
  468 |           contentType: 'application/json',
  469 |           body: JSON.stringify({ message: 'Simulated feedback failure' }),
  470 |         });
  471 |       });
  472 |       await report.fill('Automated test report');
  473 |       await page.getByRole('button', { name: /kirim laporan/i }).click();
  474 |       await expect(page.locator('body')).toContainText(/Simulated feedback failure|Gagal mengirimkan laporan/i);
  475 |       assertExpectedApiFailure(reportErrors);
  476 |       await clickIfVisible(page.getByRole('button', { name: /batal/i }));
  477 |       await page.unroute('**/api/forms/*/feedback');
  478 |     }
  479 |     await clickIfVisible(page.getByRole('button', { name: /kirim|selesai|submit/i }));
  480 |     await expect(page.locator('body')).toContainText(/wajib|jawaban|konfirmasi|formulir|koneksi/i);
  481 |   });
  482 | });
  483 | 
  484 | test.describe('FormUp - public form runner and results', () => {
  485 |   test('opens a public form link and handles loading/unavailable state', async ({ page }) => {
  486 |     await gotoApp(page, `/f/${formLink}`);
  487 |     await expect(page).toHaveURL(new RegExp(`/f/${formLink}`));
  488 |     await expect(page.locator('body')).toContainText(/formulir|memuat|tidak tersedia|sandi|koneksi/i);
  489 |   });
  490 | 
  491 |   test('opens a public result link and handles loading/error state', async ({ page }) => {
  492 |     await gotoApp(page, `/f/${formLink}/result/${responseId}`);
  493 |     await expect(page).toHaveURL(new RegExp(`/f/${formLink}/result/${responseId}`));
  494 |     await expect(page.locator('body')).toContainText(/hasil|memuat|kendala|formulir|koneksi/i);
  495 |     await clickIfVisible(page.getByRole('button', { name: /kirim laporan|masukan/i }));
  496 |     const feedback = page.locator('textarea').last();
  497 |     if (await feedback.isVisible().catch(() => false)) {
  498 |       await feedback.fill('Dry-run feedback');
  499 |       await clickIfVisible(page.getByRole('button', { name: /batal|tutup/i }));
  500 |     }
  501 |     await clickIfVisible(page.getByRole('button', { name: /lihat pembahasan|selengkapnya|detail/i }));
  502 |   });
  503 | });
  504 | 
  505 | test.describe('FormUp - browser level checks', () => {
  506 |   test('has no uncaught page exceptions on public entry points', async ({ page }) => {
  507 |     const exceptions = [];
  508 |     page.on('pageerror', (error) => exceptions.push(error.message));
  509 |     for (const path of ['/', '/login', '/register', '/forgot-password', `/f/${formLink}`]) {
  510 |       await gotoApp(page, path);
  511 |     }
  512 |     expect(exceptions, `Uncaught page exceptions: ${exceptions.join('; ')}`).toEqual([]);
  513 |   });
  514 | 
  515 |   test('supports desktop and mobile rendering without horizontal overflow', async ({ page }) => {
  516 |     for (const viewport of [{ width: 1440, height: 900 }, { width: 390, height: 844 }]) {
  517 |       await page.setViewportSize(viewport);
  518 |       await gotoApp(page, '/');
  519 |       const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
  520 |       expect(overflow, `Horizontal overflow at ${viewport.width}px`).toBe(false);
  521 |     }
  522 |   });
  523 | });
  524 | 
```