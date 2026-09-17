import { existsSync, readFileSync } from 'node:fs';
import { test, expect } from '@playwright/test';

const readDotEnv = () => {
  const values = {};
  for (const filename of ['.env', '.env.local', '.env.test']) {
    const path = new URL(`../${filename}`, import.meta.url);
    if (!existsSync(path)) continue;
    for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
      const match = line.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
      if (!match || match[1].startsWith('#')) continue;
      values[match[1]] = match[2].replace(/^(['"])(.*)\1$/, '$2');
    }
  }
  return values;
};

// Shell variables win; local env files are a dependency-free fallback for Playwright.
const env = { ...readDotEnv(), ...(globalThis.process?.env || {}) };
const baseUrl = env.BASE_URL || 'http://localhost:5173';
const formId = env.TEST_FORM_ID || 'test-form-id';
const formLink = env.TEST_FORM_LINK || 'test-form-link';
const responseId = env.TEST_RESPONSE_ID || 'test-response-id';
const hasCredentials = Boolean(env.TEST_EMAIL && env.TEST_PASSWORD);

const publicRoutes = [
  { path: '/', marker: /Buat formulir|FormUp/i },
  { path: '/login', marker: /Selamat Datang|Masuk ke Akun/i },
  { path: '/register', marker: /Registration|Daftar Sekarang/i },
  { path: '/forgot-password', marker: /Lupa Password/i },
  // Opening /verify without registration state intentionally falls back to registration.
  { path: '/verify', marker: /Verifikasi|OTP|kode|Buat Akun Baru|Nama Lengkap/i },
];

const protectedRoutes = [
  '/dashboard', '/my-forms', '/templates', '/responses', '/history',
  '/create-form', `/forms/${formId}/edit`, `/forms/${formId}/responses`,
  `/forms/${formId}/analytics`, '/admin', '/ai-chat', '/profile',
];

const waitForApp = async (page) => {
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(250);
};

const gotoApp = async (page, path) => {
  await page.goto(`${baseUrl}${path}`, { waitUntil: 'domcontentloaded' });
  await waitForApp(page);
};

const login = async (page) => {
  await gotoApp(page, '/login');
  await page.locator('input[type="email"]').fill(env.TEST_EMAIL);
  await page.locator('input[type="password"]').fill(env.TEST_PASSWORD);
  await page.getByRole('button', { name: /masuk ke akun/i }).click();
  await expect(page).toHaveURL(/\/dashboard(?:[?#].*)?$/, { timeout: 15_000 });
};

const clickIfVisible = async (locator) => {
  const target = locator.first();
  if (await target.isVisible().catch(() => false)) {
    await target.click();
    return true;
  }
  return false;
};

const fillIfVisible = async (page, locator, value) => {
  const target = locator.first();
  if (await target.isVisible().catch(() => false)) {
    await target.fill(value);
    return true;
  }
  return false;
};

const assertNoReactCrash = async (page) => {
  await expect(page.locator('body')).not.toContainText(/Application error|Cannot read properties of undefined/i);
};

const observeRuntimeErrors = (page) => {
  const problems = { page: [], console: [], requests: [], api: [] };
  page.on('pageerror', (error) => problems.page.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') problems.console.push(message.text());
  });
  page.on('requestfailed', (request) => {
    problems.requests.push(`${request.method()} ${request.url()} — ${request.failure()?.errorText || 'failed'}`);
  });
  page.on('response', (response) => {
    if (response.status() >= 400 && /\/api\//i.test(response.url())) {
      problems.api.push({ status: response.status(), method: response.request().method(), url: response.url() });
    }
  });
  return problems;
};

const assertExpectedApiFailure = (problems, status = 500) => {
  expect(problems.api.some((entry) => entry.status === status), `API ${status} was not captured: ${JSON.stringify(problems.api)}`).toBe(true);
  expect(problems.page, `Unhandled page exceptions: ${problems.page.join('; ')}`).toEqual([]);
};

test.describe('FormUp - public pages and authentication', () => {
  test('renders every public route', async ({ page }) => {
    for (const route of publicRoutes) {
      await gotoApp(page, route.path);
      await expect(page.locator('body')).toContainText(route.marker);
    }
  });

  test('landing navigation reaches login and registration', async ({ page }) => {
    await gotoApp(page, '/');
    await page.getByRole('link', { name: /masuk|login/i }).first().click();
    await expect(page).toHaveURL(/\/login/);
    await page.getByRole('link', { name: /daftar/i }).first().click();
    await expect(page).toHaveURL(/\/register/);
  });

  test('login validates required fields and invalid credentials', async ({ page }) => {
    await page.route('**/api/auth/login', async (route) => {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({ message: 'Email atau password salah.' }),
      });
    });
    await gotoApp(page, '/login');
    await page.getByRole('button', { name: /masuk ke akun/i }).click();
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await page.locator('input[type="email"]').fill('invalid-formup-test@example.com');
    await page.locator('input[type="password"]').fill('wrong-password');
    await page.getByRole('button', { name: /masuk ke akun/i }).click();
    await expect(page.locator('body')).toContainText(/salah|kesalahan|koneksi|error/i);
  });

  test('register form exposes fields and client validation', async ({ page }) => {
    await gotoApp(page, '/register');
    await expect(page.getByPlaceholder('Nama Lengkap')).toBeVisible();
    await expect(page.getByPlaceholder('username')).toBeVisible();
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.getByPlaceholder('Min. 8 karakter')).toBeVisible();
    await expect(page.getByPlaceholder('Ulangi password')).toBeVisible();
    await page.getByPlaceholder('Nama Lengkap').fill('Playwright Tester');
    await page.getByPlaceholder('username').fill('playwright_tester');
    await page.locator('input[type="email"]').fill('playwright@example.com');
    await page.locator('input[type="date"]').fill('2000-01-01');
    await page.getByPlaceholder('Min. 8 karakter').fill('password-123');
    await page.getByPlaceholder('Ulangi password').fill('different-password');
    await page.getByRole('button', { name: /daftar sekarang/i }).click();
    await expect(page.locator('body')).toContainText(/tidak cocok|password|konfirmasi/i);
    await expect(page).toHaveURL(/\/register/);
  });

  test('forgot-password flow exposes the OTP request state', async ({ page }) => {
    await page.route('**/api/auth/forgot-password', async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ data: true }) });
    });
    await page.route('**/api/auth/reset-password', async (route) => {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ data: true }) });
    });
    await gotoApp(page, '/forgot-password');
    await page.getByPlaceholder('nama@email.com').fill('playwright@example.com');
    await page.getByRole('button', { name: /kirim kode otp/i }).click();
    await expect(page.getByPlaceholder('123456')).toBeVisible();
    await page.getByPlaceholder('123456').fill('12345');
    await page.getByPlaceholder('Minimal 8 karakter').fill('password-123');
    await page.getByPlaceholder('Ulangi password baru').fill('different-password');
    await page.getByRole('button', { name: /reset password/i }).click();
    await expect(page.locator('body')).toContainText(/tidak cocok|password/i);
    await page.getByPlaceholder('Ulangi password baru').fill('password-123');
    await page.getByRole('button', { name: /reset password/i }).click();
    await expect(page.locator('body')).toContainText(/berhasil diubah|kembali ke login/i);
  });
});

test.describe('FormUp - protected application routes', () => {
  test('redirects unauthenticated users from every protected route', async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.clear();
      sessionStorage.clear();
    });
    for (const path of protectedRoutes) {
      await gotoApp(page, path);
      await expect(page).toHaveURL(/\/login(?:[?#].*)?$/);
    }
  });

  test('login once and run the complete authenticated flow without changing account data', async ({ page }) => {
    test.skip(!hasCredentials, 'TEST_EMAIL dan TEST_PASSWORD wajib tersedia.');
    await login(page);

    // Satu sesi ini sengaja mengalir terus; tidak ada login/logout di tengah flow.
    for (const path of protectedRoutes.filter((path) => path !== '/create-form')) {
      await gotoApp(page, path);
      await expect(page).not.toHaveURL(/\/login/);
      await assertNoReactCrash(page);
    }

    await gotoApp(page, '/dashboard');
    await clickIfVisible(page.getByRole('button', { name: /buat formulir/i }).first());
    await expect(page.locator('body')).toContainText(/buat manual|buat dengan ai|dashboard/i);
    const search = page.getByPlaceholder(/cari formulir/i);
    if (await search.isVisible().catch(() => false)) await search.fill('FormUp test');
    await clickIfVisible(page.getByRole('button', { name: /coba ai form builder/i }));
    await expect(page.locator('body')).toContainText(/AI|generate|form builder/i);
    await clickIfVisible(page.getByRole('button', { name: /tutup|batal|cancel/i }));
    await clickIfVisible(page.getByRole('button', { name: /butuh panduan|pelajari cara/i }));
    await expect(page.locator('body')).toContainText(/panduan|tour|formup/i);
    await clickIfVisible(page.getByTitle(/tutup modal|close/i));

    const createErrors = observeRuntimeErrors(page);
    await page.route('**/api/forms', async (route) => {
      if (route.request().method() === 'POST') {
        await route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ message: 'Simulated create-form failure' }),
        });
      } else {
        await route.continue();
      }
    });
    await gotoApp(page, '/create-form');
    await expect(page.locator('body')).toContainText(/Gagal Membuat Formulir|Simulated create-form failure/i);
    assertExpectedApiFailure(createErrors);
    await page.unroute('**/api/forms');

    // Uji alur pembuatan sampai redirect tanpa membuat data sungguhan di akun.
    await page.route('**/api/forms', async (route) => {
      if (route.request().method() === 'POST') {
        await route.fulfill({
          status: 201,
          contentType: 'application/json',
          body: JSON.stringify({ data: { id: 'playwright-dry-run-form' } }),
        });
      } else {
        await route.continue();
      }
    });
    await gotoApp(page, '/create-form');
    await expect(page).toHaveURL(/\/forms\/playwright-dry-run-form\/edit/);
    await page.unroute('**/api/forms');

    await clickIfVisible(page.getByTitle('Mode Gelap'));
    await expect(page.locator('html')).toHaveClass(/dark/);
    await clickIfVisible(page.getByTitle('Mode Terang'));
    for (const item of [/Formulir Saya/i, /Respons/i, /Templat/i, /Riwayat/i]) {
      const nav = page.getByRole('button', { name: item }).first();
      if (await nav.isVisible().catch(() => false)) await nav.click();
      await assertNoReactCrash(page);
    }

    await gotoApp(page, '/my-forms');
    await page.getByPlaceholder('Cari formulir Anda...').fill('FormUp');
    await clickIfVisible(page.getByTitle('Halaman Selanjutnya'));
    await clickIfVisible(page.getByTitle('Halaman Sebelumnya'));

    await gotoApp(page, '/templates');
    await page.getByPlaceholder(/cari templat/i).fill('kuis');
    await assertNoReactCrash(page);
    // Tidak menekan "Gunakan Templat" karena itu membuat data baru.

    await gotoApp(page, '/responses');
    await page.getByPlaceholder(/cari formulir, responden, atau jawaban/i).fill('test');
    await gotoApp(page, '/history');
    await page.getByPlaceholder(/cari riwayat formulir/i).fill('test');

    await gotoApp(page, '/profile');
    await expect(page.locator('body')).toContainText(/Pengaturan Akun|Informasi Pribadi/i);
    const fullname = page.getByLabel('Nama Lengkap');
    if (await fullname.isVisible().catch(() => false)) {
      const original = await fullname.inputValue();
      await fullname.fill(original);
    }
    // Hanya uji validasi mismatch; tidak menekan tombol simpan.
    const currentPassword = page.getByPlaceholder('Masukkan kata sandi saat ini');
    if (await currentPassword.isVisible().catch(() => false)) {
      await currentPassword.fill('test-current-password');
      await page.getByPlaceholder('Min. 8 karakter').last().fill('temporary-test-password');
      await page.getByPlaceholder('Ulangi password baru').fill('different-password');
      await expect(page.locator('body')).toContainText(/password|kata sandi/i);
    }

    await gotoApp(page, '/ai-chat');
    await expect(page.locator('body')).toContainText(/AI Assistant|Nilai Tertinggi|Deteksi Kecurangan/i);
    await clickIfVisible(page.getByRole('button', { name: /pengaturan|api key|kunci api/i }));
    const keyInput = page.locator('textarea[placeholder*="AIzaSyKey"]').first();
    if (await keyInput.isVisible().catch(() => false)) {
      await keyInput.fill('playwright-validation-key');
      // Tutup modal tanpa menyimpan key.
      await clickIfVisible(page.getByRole('button', { name: /batal|tutup|cancel/i }));
    }
    await clickIfVisible(page.getByRole('button', { name: /nilai tertinggi|deteksi kecurangan|evaluasi butir|bulk export/i }).first());
    const chatInput = page.locator('textarea').last();
    if (await chatInput.isVisible().catch(() => false)) await chatInput.fill('Validasi input chat tanpa mengirim');
    await assertNoReactCrash(page);

    if (env.TEST_FORM_ID) {
      await gotoApp(page, `/forms/${formId}/edit`);
      await expect(page.locator('body')).toContainText(/Form Builder|Memuat builder|Judul Formulir/i);
      const title = page.getByPlaceholder('Judul Formulir...');
      if (await title.isVisible().catch(() => false)) {
        const originalTitle = await title.inputValue();
        await title.fill(`${originalTitle} [validation]`);
        await title.fill(originalTitle);
      }
      await clickIfVisible(page.getByRole('button', { name: /pengaturan & aturan/i }));
      await expect(page.locator('body')).toContainText(/Konfigurasi & Aturan Formulir/i);
      const slug = page.getByPlaceholder('tautan-khusus-saya');
      if (await slug.isVisible().catch(() => false)) {
        const originalSlug = await slug.inputValue();
        await slug.fill('playwright-dry-run');
        await slug.fill(originalSlug);
      }
      await page.getByPlaceholder('contoh: 30').fill('30');
      await page.getByPlaceholder('contoh: RAHASIA123').fill('DRY-RUN');
      await clickIfVisible(page.getByText('Aktifkan Mode Ujian', { exact: true }));
      await clickIfVisible(page.getByText('Deteksi Pindah Tab / Minimize', { exact: true }));
      const settingsErrors = observeRuntimeErrors(page);
      await page.route(`**/api/forms/${formId}/settings`, async (route) => {
        await route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ message: 'Simulated settings save failure' }),
        });
      });
      await clickIfVisible(page.getByRole('button', { name: /simpan pengaturan/i }));
      await expect(page.locator('body')).toContainText(/Simulated settings save failure|Gagal menyimpan pengaturan/i);
      assertExpectedApiFailure(settingsErrors);
      await page.unroute(`**/api/forms/${formId}/settings`);
      await clickIfVisible(page.getByRole('button', { name: /bagikan & kode qr/i }));
      await expect(page.locator('body')).toContainText(/Bagikan Tautan|Tautan Publik|Kode QR/i);
      await clickIfVisible(page.getByRole('button', { name: /salin tautan/i }));
      await clickIfVisible(page.getByRole('button', { name: /pertanyaan & soal/i }));
      await clickIfVisible(page.getByRole('button', { name: /tambah soal|tambah pertanyaan/i }));
      await clickIfVisible(page.getByTitle('Toggle Live Preview'));
      await clickIfVisible(page.getByTitle('Panduan Form Builder'));
      await clickIfVisible(page.getByRole('button', { name: /generate soal ai/i }));
      const aiTopic = page.getByPlaceholder(/contoh: kuis ujian akhir/i);
      if (await aiTopic.isVisible().catch(() => false)) {
        await aiTopic.fill('Dry-run materi matematika');
        await clickIfVisible(page.getByText('Rumus (KaTeX)', { exact: true }));
        await clickIfVisible(page.getByText('Code Block', { exact: true }));
        await clickIfVisible(page.getByText(/Opsi Tambahan/i));
        await fillIfVisible(page, page.getByPlaceholder(/tempel teks materi/i), 'Materi dry-run');
        await clickIfVisible(page.getByRole('button', { name: /tutup|batal|cancel/i }));
      }
      await clickIfVisible(page.getByRole('button', { name: /impor|import/i }));
      await expect(page.locator('body')).toContainText(/import|impor|pertanyaan/i);
      await clickIfVisible(page.getByTitle('Tutup'));
      await clickIfVisible(page.getByTitle('Menu Tindakan Cepat'));
      await clickIfVisible(page.getByRole('button', { name: /revisi massal ai/i }));
      await fillIfVisible(page, page.getByPlaceholder(/instruksi revisi untuk semua soal/i), 'Dry-run revisi');
      await clickIfVisible(page.getByRole('button', { name: /selesai pilih|revisi massal ai/i }));
      await clickIfVisible(page.getByRole('button', { name: /undo/i }));
      await clickIfVisible(page.getByRole('button', { name: /redo/i }));
      await clickIfVisible(page.getByRole('button', { name: /export soal \(csv\)/i }));

      await gotoApp(page, `/forms/${formId}/responses`);
      await expect(page.locator('body')).toContainText(/Respons|Memuat respons|Daftar Respons/i);
      await clickIfVisible(page.getByRole('button', { name: /monitoring/i }));
      await clickIfVisible(page.getByRole('button', { name: /laporan|masukan|feedback/i }));
      await clickIfVisible(page.getByTitle('Segarkan Data Monitoring'));
      await clickIfVisible(page.getByPlaceholder(/cari nama responden/i));
      await clickIfVisible(page.getByTitle('Unduh format CSV'));
      await clickIfVisible(page.getByTitle('Unduh format Excel (.xlsx)'));
      await clickIfVisible(page.getByTitle('Unduh format PDF (.pdf)'));

      await gotoApp(page, `/forms/${formId}/analytics`);
      await expect(page.locator('body')).toContainText(/Analisis|Memuat analisis|Diagram/i);
      await page.locator('select[aria-label="Model Analisis Pintar"]').selectOption({ index: 0 }).catch(() => {});
      await clickIfVisible(page.getByTitle('Export ke Excel (.xlsx)'));
      await clickIfVisible(page.getByTitle('Export ke CSV (.csv)'));
      await clickIfVisible(page.getByTitle('Export ke PDF (.pdf)'));
    }

    await gotoApp(page, '/admin');
    if (!(await page.getByText(/akses ditolak|khusus admin|tidak memiliki akses/i).first().isVisible().catch(() => false))) {
      const adminSearch = page.getByPlaceholder('Cari data...');
      if (await adminSearch.isVisible().catch(() => false)) await adminSearch.fill('test');
      await clickIfVisible(page.getByRole('button', { name: /pengguna|users/i }));
      await clickIfVisible(page.getByRole('button', { name: /formulir|forms/i }));
      await clickIfVisible(page.getByRole('button', { name: /umpan balik|feedback/i }));
    }
    await assertNoReactCrash(page);

    // Auth lifecycle: logout memang diuji di akhir setelah seluruh fitur selesai.
    await gotoApp(page, '/dashboard');
    await clickIfVisible(page.getByRole('button', { name: /keluar/i }));
    const logoutConfirm = page.getByRole('button', { name: /ya, lanjutkan|keluar/i }).last();
    if (await logoutConfirm.isVisible().catch(() => false)) await logoutConfirm.click();
    await expect(page).toHaveURL(/\/login/);
    await login(page);
    await expect(page).toHaveURL(/\/dashboard/);
  });
});

test.describe('FormUp - detailed public respondent flow', () => {
  test('captures and displays a server error when submitting a form fails', async ({ page }) => {
    const errorLink = 'playwright-error-submit-form';
    const problems = observeRuntimeErrors(page);
    await page.route(`**/api/public/forms/${errorLink}`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          data: {
            id: 99001,
            title: 'Playwright Error Handling Form',
            formLink: errorLink,
            formTypeId: 1,
            requiresToken: false,
            oneResponse: false,
            showScore: false,
          },
        }),
      });
    });
    await page.route(`**/api/public/forms/${errorLink}/questions`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ data: [{ id: 990011, typeId: 1, question: '<p>Describe your answer</p>', isRequired: false }] }),
      });
    });
    await page.route(`**/api/public/forms/${errorLink}/responses`, async (route) => {
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({ message: 'Simulated submit failure' }),
      });
    });

    await gotoApp(page, `/f/${errorLink}`);
    await expect(page.getByText('Playwright Error Handling Form')).toBeVisible();
    await page.getByPlaceholder(/masukkan nama lengkap/i).fill('Error Test Respondent');
    await page.getByPlaceholder(/ketikkan jawaban/i).fill('This answer is only for the error test.');
    await page.getByRole('button', { name: /kirim formulir/i }).click();
    await expect(page.locator('body')).toContainText(/Simulated submit failure|Gagal mengirimkan respons formulir/i);
    assertExpectedApiFailure(problems);
  });

  test('form runner supports respondent identity, theme, navigation, reporting, and validation', async ({ page }) => {
    await gotoApp(page, `/f/${formLink}`);
    await expect(page).toHaveURL(new RegExp(`/f/${formLink}`));
    const accessToken = page.getByPlaceholder('Masukkan token sandi...');
    if (await accessToken.isVisible().catch(() => false)) {
      await accessToken.fill('invalid-dry-run-token');
      await page.getByRole('button', { name: /buka formulir/i }).click();
      await expect(page.locator('body')).toContainText(/sandi|token|gagal|tidak tersedia/i);
      return;
    }
    const name = page.getByPlaceholder(/masukkan nama lengkap/i);
    if (!(await name.isVisible().catch(() => false))) {
      await expect(page.locator('body')).toContainText(/tidak tersedia|memuat|sandi|formulir/i);
      return;
    }
    await name.fill('Playwright Respondent');
    await clickIfVisible(page.getByRole('button', { name: /mode gelap/i }));
    await clickIfVisible(page.getByRole('button', { name: /navigasi soal cepat/i }));
    await clickIfVisible(page.getByRole('button', { name: /laporkan masalah/i }));
    const report = page.getByPlaceholder(/ceritakan detail kendala/i);
    if (await report.isVisible().catch(() => false)) {
      const reportErrors = observeRuntimeErrors(page);
      await page.route('**/api/forms/*/feedback', async (route) => {
        await route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ message: 'Simulated feedback failure' }),
        });
      });
      await report.fill('Automated test report');
      await page.getByRole('button', { name: /kirim laporan/i }).click();
      await expect(page.locator('body')).toContainText(/Simulated feedback failure|Gagal mengirimkan laporan/i);
      assertExpectedApiFailure(reportErrors);
      await clickIfVisible(page.getByRole('button', { name: /batal/i }));
      await page.unroute('**/api/forms/*/feedback');
    }
    await clickIfVisible(page.getByRole('button', { name: /kirim|selesai|submit/i }));
    await expect(page.locator('body')).toContainText(/wajib|jawaban|konfirmasi|formulir|koneksi/i);
  });
});

test.describe('FormUp - public form runner and results', () => {
  test('opens a public form link and handles loading/unavailable state', async ({ page }) => {
    await gotoApp(page, `/f/${formLink}`);
    await expect(page).toHaveURL(new RegExp(`/f/${formLink}`));
    await expect(page.locator('body')).toContainText(/formulir|memuat|tidak tersedia|sandi|koneksi/i);
  });

  test('opens a public result link and handles loading/error state', async ({ page }) => {
    await gotoApp(page, `/f/${formLink}/result/${responseId}`);
    await expect(page).toHaveURL(new RegExp(`/f/${formLink}/result/${responseId}`));
    await expect(page.locator('body')).toContainText(/hasil|memuat|kendala|formulir|koneksi/i);
    await clickIfVisible(page.getByRole('button', { name: /kirim laporan|masukan/i }));
    const feedback = page.locator('textarea').last();
    if (await feedback.isVisible().catch(() => false)) {
      await feedback.fill('Dry-run feedback');
      await clickIfVisible(page.getByRole('button', { name: /batal|tutup/i }));
    }
    await clickIfVisible(page.getByRole('button', { name: /lihat pembahasan|selengkapnya|detail/i }));
  });
});

test.describe('FormUp - browser level checks', () => {
  test('has no uncaught page exceptions on public entry points', async ({ page }) => {
    const exceptions = [];
    page.on('pageerror', (error) => exceptions.push(error.message));
    for (const path of ['/', '/login', '/register', '/forgot-password', `/f/${formLink}`]) {
      await gotoApp(page, path);
    }
    expect(exceptions, `Uncaught page exceptions: ${exceptions.join('; ')}`).toEqual([]);
  });

  test('supports desktop and mobile rendering without horizontal overflow', async ({ page }) => {
    for (const viewport of [{ width: 1440, height: 900 }, { width: 390, height: 844 }]) {
      await page.setViewportSize(viewport);
      await gotoApp(page, '/');
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
      expect(overflow, `Horizontal overflow at ${viewport.width}px`).toBe(false);
    }
  });
});
