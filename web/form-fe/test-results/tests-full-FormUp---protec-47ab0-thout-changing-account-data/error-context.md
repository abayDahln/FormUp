# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: tests/full.spec.js >> FormUp - protected application routes >> login once and run the complete authenticated flow without changing account data
- Location: tests/full.spec.js:188:3

# Error details

```
Error: expect(locator).toHaveClass(expected) failed

Locator: locator('html')
Expected pattern: /dark/
Received string:  ""
Timeout: 5000ms

Call log:
  - Expect "toHaveClass" locator('html') with timeout 5000ms
  - waiting for locator('html')
    13 × locator resolved to <html lang="id" data-theme="light">…</html>
       - unexpected value ""

```

```yaml
- document:
  - complementary
  - button
  - heading "Formulir Tanpa Judul" [level=1]
  - text: Draf
  - paragraph: /f/
  - button "Publikasikan"
  - button "Preview"
  - button "Dual View OFF"
  - button "Auto-Save OFF"
  - button "Simpan Perubahan"
  - button "Panduan"
  - button "Pertanyaan & Soal"
  - button "Pengaturan & Aturan"
  - button "Bagikan & Kode QR"
  - text: Judul Formulir
  - textbox "Judul Formulir..."
  - text: Deskripsi Formulir
  - button "+ Teks WYSIWYG"
  - button "+ Blok Kode"
  - button "+ Rumus KaTeX"
  - text: "Blok Teks #1"
  - button "Pindah ke Atas" [disabled]
  - button "Pindah ke Bawah" [disabled]
  - button "Hapus Blok"
  - button "Tebal (Bold)"
  - button "Miring (Italic)"
  - button "Garis Bawah (Underline)"
  - button "Coret (Strikethrough)"
  - button "Warna Font Teks"
  - button "Warna Sorot (Highlight Background)"
  - button "Normal"
  - button "H1"
  - button "H2"
  - button "H3"
  - button "Kecil"
  - button "Rata Kiri"
  - button "Rata Tengah"
  - button "Rata Kanan"
  - button "Rata Kiri Kanan (Justify)"
  - button "Daftar Poin (Bullet List)"
  - button "Daftar Nomor (Numbered List)"
  - button "Kutipan (Blockquote)"
  - button "Sisipkan Tautan URL"
  - button "$Rumus$"
  - button "Editor Rumus Visual"
  - button "Hapus Format (Clear Formatting)"
  - textbox: Tuliskan petunjuk atau deskripsi umum formulir...
  - button "Tambah Paragraf Teks"
  - text: Belum Ada Gambar Banner Unggah Banner
  - paragraph: Total Maksimal Skor
  - paragraph: 1 poin
  - paragraph: Jumlah Soal
  - paragraph: 1 soal
  - paragraph: Buat Soal Otomatis dengan AI
  - paragraph: Ketik topik atau paste materi, AI menyusun soal, opsi, dan kunci jawaban instan.
  - button "Generate Soal AI"
  - text: "Template:"
  - link ".CSV":
    - /url: https://api.formup.my.id/api/templates/import-questions?format=csv
  - link ".XLSX":
    - /url: https://api.formup.my.id/api/templates/import-questions?format=xlsx
  - link ".DOCX":
    - /url: https://api.formup.my.id/api/templates/import-questions?format=docx
  - button "Impor File (Preview Dulu)"
  - textbox "Cari soal berdasarkan teks..."
  - img
  - text: "Belum ada soal · Tambahkan soal atau impor dari file Soal #1"
  - button "Toggle Live Preview"
  - button "Revisi soal dengan AI"
  - button "Pindah Naik" [disabled]
  - button "Pindah Turun" [disabled]
  - button "Duplikat Soal"
  - button "Hapus Soal"
  - text: Tambah Gambar Soal Tambah Audio Soal Isi Pertanyaan Soal
  - button "+ Teks WYSIWYG"
  - button "+ Blok Kode"
  - button "+ Rumus KaTeX"
  - text: "Blok Teks #1"
  - button "Pindah ke Atas" [disabled]
  - button "Pindah ke Bawah" [disabled]
  - button "Hapus Blok"
  - button "Tebal (Bold)"
  - button "Miring (Italic)"
  - button "Garis Bawah (Underline)"
  - button "Coret (Strikethrough)"
  - button "Warna Font Teks"
  - button "Warna Sorot (Highlight Background)"
  - button "Normal"
  - button "H1"
  - button "H2"
  - button "H3"
  - button "Kecil"
  - button "Rata Kiri"
  - button "Rata Tengah"
  - button "Rata Kanan"
  - button "Rata Kiri Kanan (Justify)"
  - button "Daftar Poin (Bullet List)"
  - button "Daftar Nomor (Numbered List)"
  - button "Kutipan (Blockquote)"
  - button "Sisipkan Tautan URL"
  - button "$Rumus$"
  - button "Editor Rumus Visual"
  - button "Hapus Format (Clear Formatting)"
  - textbox: Tuliskan teks pertanyaan soal, kode program, atau rumus...
  - button "Tambah Paragraf Teks"
  - text: Tipe Soal
  - combobox
  - checkbox "Hitung ke Skor (Dinilai)" [checked]
  - text: Hitung ke Skor (Dinilai)
  - checkbox "Soal Wajib Diisi" [checked]
  - text: Soal Wajib Diisi Poin Soal
  - spinbutton "Kosongi = bobot sama rata"
  - text: "opsional — biarkan kosong untuk bobot sama rata Pilihan Jawaban: ● Pilih 1 jawaban benar (radio)"
  - radio
  - textbox "Pilihan 1"
  - button "Sisipkan Rumus (KaTeX)"
  - button "Sisipkan Kode Block"
  - button
  - radio
  - textbox "Pilihan 2"
  - button "Sisipkan Rumus (KaTeX)"
  - button "Sisipkan Kode Block"
  - button
  - button "+ Tambah Pilihan"
  - button "Tambah Soal Manual"
  - button "Menu Tindakan Cepat"
```

# Test source

```ts
  145 |     await page.locator('input[type="email"]').fill('playwright@example.com');
  146 |     await page.locator('input[type="date"]').fill('2000-01-01');
  147 |     await page.getByPlaceholder('Min. 8 karakter').fill('password-123');
  148 |     await page.getByPlaceholder('Ulangi password').fill('different-password');
  149 |     await page.getByRole('button', { name: /daftar sekarang/i }).click();
  150 |     await expect(page.locator('body')).toContainText(/tidak cocok|password|konfirmasi/i);
  151 |     await expect(page).toHaveURL(/\/register/);
  152 |   });
  153 | 
  154 |   test('forgot-password flow exposes the OTP request state', async ({ page }) => {
  155 |     await page.route('**/api/auth/forgot-password', async (route) => {
  156 |       await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ data: true }) });
  157 |     });
  158 |     await page.route('**/api/auth/reset-password', async (route) => {
  159 |       await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ data: true }) });
  160 |     });
  161 |     await gotoApp(page, '/forgot-password');
  162 |     await page.getByPlaceholder('nama@email.com').fill('playwright@example.com');
  163 |     await page.getByRole('button', { name: /kirim kode otp/i }).click();
  164 |     await expect(page.getByPlaceholder('123456')).toBeVisible();
  165 |     await page.getByPlaceholder('123456').fill('12345');
  166 |     await page.getByPlaceholder('Minimal 8 karakter').fill('password-123');
  167 |     await page.getByPlaceholder('Ulangi password baru').fill('different-password');
  168 |     await page.getByRole('button', { name: /reset password/i }).click();
  169 |     await expect(page.locator('body')).toContainText(/tidak cocok|password/i);
  170 |     await page.getByPlaceholder('Ulangi password baru').fill('password-123');
  171 |     await page.getByRole('button', { name: /reset password/i }).click();
  172 |     await expect(page.locator('body')).toContainText(/berhasil diubah|kembali ke login/i);
  173 |   });
  174 | });
  175 | 
  176 | test.describe('FormUp - protected application routes', () => {
  177 |   test('redirects unauthenticated users from every protected route', async ({ page }) => {
  178 |     await page.addInitScript(() => {
  179 |       localStorage.clear();
  180 |       sessionStorage.clear();
  181 |     });
  182 |     for (const path of protectedRoutes) {
  183 |       await gotoApp(page, path);
  184 |       await expect(page).toHaveURL(/\/login(?:[?#].*)?$/);
  185 |     }
  186 |   });
  187 | 
  188 |   test('login once and run the complete authenticated flow without changing account data', async ({ page }) => {
  189 |     test.skip(!hasCredentials, 'TEST_EMAIL dan TEST_PASSWORD wajib tersedia.');
  190 |     await login(page);
  191 | 
  192 |     // Satu sesi ini sengaja mengalir terus; tidak ada login/logout di tengah flow.
  193 |     for (const path of protectedRoutes.filter((path) => path !== '/create-form')) {
  194 |       await gotoApp(page, path);
  195 |       await expect(page).not.toHaveURL(/\/login/);
  196 |       await assertNoReactCrash(page);
  197 |     }
  198 | 
  199 |     await gotoApp(page, '/dashboard');
  200 |     await clickIfVisible(page.getByRole('button', { name: /buat formulir/i }).first());
  201 |     await expect(page.locator('body')).toContainText(/buat manual|buat dengan ai|dashboard/i);
  202 |     const search = page.getByPlaceholder(/cari formulir/i);
  203 |     if (await search.isVisible().catch(() => false)) await search.fill('FormUp test');
  204 |     await clickIfVisible(page.getByRole('button', { name: /coba ai form builder/i }));
  205 |     await expect(page.locator('body')).toContainText(/AI|generate|form builder/i);
  206 |     await clickIfVisible(page.getByRole('button', { name: /tutup|batal|cancel/i }));
  207 |     await clickIfVisible(page.getByRole('button', { name: /butuh panduan|pelajari cara/i }));
  208 |     await expect(page.locator('body')).toContainText(/panduan|tour|formup/i);
  209 |     await clickIfVisible(page.getByTitle(/tutup modal|close/i));
  210 | 
  211 |     const createErrors = observeRuntimeErrors(page);
  212 |     await page.route('**/api/forms', async (route) => {
  213 |       if (route.request().method() === 'POST') {
  214 |         await route.fulfill({
  215 |           status: 500,
  216 |           contentType: 'application/json',
  217 |           body: JSON.stringify({ message: 'Simulated create-form failure' }),
  218 |         });
  219 |       } else {
  220 |         await route.continue();
  221 |       }
  222 |     });
  223 |     await gotoApp(page, '/create-form');
  224 |     await expect(page.locator('body')).toContainText(/Gagal Membuat Formulir|Simulated create-form failure/i);
  225 |     assertExpectedApiFailure(createErrors);
  226 |     await page.unroute('**/api/forms');
  227 | 
  228 |     // Uji alur pembuatan sampai redirect tanpa membuat data sungguhan di akun.
  229 |     await page.route('**/api/forms', async (route) => {
  230 |       if (route.request().method() === 'POST') {
  231 |         await route.fulfill({
  232 |           status: 201,
  233 |           contentType: 'application/json',
  234 |           body: JSON.stringify({ data: { id: 'playwright-dry-run-form' } }),
  235 |         });
  236 |       } else {
  237 |         await route.continue();
  238 |       }
  239 |     });
  240 |     await gotoApp(page, '/create-form');
  241 |     await expect(page).toHaveURL(/\/forms\/playwright-dry-run-form\/edit/);
  242 |     await page.unroute('**/api/forms');
  243 | 
  244 |     await clickIfVisible(page.getByTitle('Mode Gelap'));
> 245 |     await expect(page.locator('html')).toHaveClass(/dark/);
      |                                        ^ Error: expect(locator).toHaveClass(expected) failed
  246 |     await clickIfVisible(page.getByTitle('Mode Terang'));
  247 |     for (const item of [/Formulir Saya/i, /Respons/i, /Templat/i, /Riwayat/i]) {
  248 |       const nav = page.getByRole('button', { name: item }).first();
  249 |       if (await nav.isVisible().catch(() => false)) await nav.click();
  250 |       await assertNoReactCrash(page);
  251 |     }
  252 | 
  253 |     await gotoApp(page, '/my-forms');
  254 |     await page.getByPlaceholder('Cari formulir Anda...').fill('FormUp');
  255 |     await clickIfVisible(page.getByTitle('Halaman Selanjutnya'));
  256 |     await clickIfVisible(page.getByTitle('Halaman Sebelumnya'));
  257 | 
  258 |     await gotoApp(page, '/templates');
  259 |     await page.getByPlaceholder(/cari templat/i).fill('kuis');
  260 |     await assertNoReactCrash(page);
  261 |     // Tidak menekan "Gunakan Templat" karena itu membuat data baru.
  262 | 
  263 |     await gotoApp(page, '/responses');
  264 |     await page.getByPlaceholder(/cari formulir, responden, atau jawaban/i).fill('test');
  265 |     await gotoApp(page, '/history');
  266 |     await page.getByPlaceholder(/cari riwayat formulir/i).fill('test');
  267 | 
  268 |     await gotoApp(page, '/profile');
  269 |     await expect(page.locator('body')).toContainText(/Pengaturan Akun|Informasi Pribadi/i);
  270 |     const fullname = page.getByLabel('Nama Lengkap');
  271 |     if (await fullname.isVisible().catch(() => false)) {
  272 |       const original = await fullname.inputValue();
  273 |       await fullname.fill(original);
  274 |     }
  275 |     // Hanya uji validasi mismatch; tidak menekan tombol simpan.
  276 |     const currentPassword = page.getByPlaceholder('Masukkan kata sandi saat ini');
  277 |     if (await currentPassword.isVisible().catch(() => false)) {
  278 |       await currentPassword.fill('test-current-password');
  279 |       await page.getByPlaceholder('Min. 8 karakter').last().fill('temporary-test-password');
  280 |       await page.getByPlaceholder('Ulangi password baru').fill('different-password');
  281 |       await expect(page.locator('body')).toContainText(/password|kata sandi/i);
  282 |     }
  283 | 
  284 |     await gotoApp(page, '/ai-chat');
  285 |     await expect(page.locator('body')).toContainText(/AI Assistant|Nilai Tertinggi|Deteksi Kecurangan/i);
  286 |     await clickIfVisible(page.getByRole('button', { name: /pengaturan|api key|kunci api/i }));
  287 |     const keyInput = page.locator('textarea[placeholder*="AIzaSyKey"]').first();
  288 |     if (await keyInput.isVisible().catch(() => false)) {
  289 |       await keyInput.fill('playwright-validation-key');
  290 |       // Tutup modal tanpa menyimpan key.
  291 |       await clickIfVisible(page.getByRole('button', { name: /batal|tutup|cancel/i }));
  292 |     }
  293 |     await clickIfVisible(page.getByRole('button', { name: /nilai tertinggi|deteksi kecurangan|evaluasi butir|bulk export/i }).first());
  294 |     const chatInput = page.locator('textarea').last();
  295 |     if (await chatInput.isVisible().catch(() => false)) await chatInput.fill('Validasi input chat tanpa mengirim');
  296 |     await assertNoReactCrash(page);
  297 | 
  298 |     if (env.TEST_FORM_ID) {
  299 |       await gotoApp(page, `/forms/${formId}/edit`);
  300 |       await expect(page.locator('body')).toContainText(/Form Builder|Memuat builder|Judul Formulir/i);
  301 |       const title = page.getByPlaceholder('Judul Formulir...');
  302 |       if (await title.isVisible().catch(() => false)) {
  303 |         const originalTitle = await title.inputValue();
  304 |         await title.fill(`${originalTitle} [validation]`);
  305 |         await title.fill(originalTitle);
  306 |       }
  307 |       await clickIfVisible(page.getByRole('button', { name: /pengaturan & aturan/i }));
  308 |       await expect(page.locator('body')).toContainText(/Konfigurasi & Aturan Formulir/i);
  309 |       const slug = page.getByPlaceholder('tautan-khusus-saya');
  310 |       if (await slug.isVisible().catch(() => false)) {
  311 |         const originalSlug = await slug.inputValue();
  312 |         await slug.fill('playwright-dry-run');
  313 |         await slug.fill(originalSlug);
  314 |       }
  315 |       await page.getByPlaceholder('contoh: 30').fill('30');
  316 |       await page.getByPlaceholder('contoh: RAHASIA123').fill('DRY-RUN');
  317 |       await clickIfVisible(page.getByText('Aktifkan Mode Ujian', { exact: true }));
  318 |       await clickIfVisible(page.getByText('Deteksi Pindah Tab / Minimize', { exact: true }));
  319 |       const settingsErrors = observeRuntimeErrors(page);
  320 |       await page.route(`**/api/forms/${formId}/settings`, async (route) => {
  321 |         await route.fulfill({
  322 |           status: 500,
  323 |           contentType: 'application/json',
  324 |           body: JSON.stringify({ message: 'Simulated settings save failure' }),
  325 |         });
  326 |       });
  327 |       await clickIfVisible(page.getByRole('button', { name: /simpan pengaturan/i }));
  328 |       await expect(page.locator('body')).toContainText(/Simulated settings save failure|Gagal menyimpan pengaturan/i);
  329 |       assertExpectedApiFailure(settingsErrors);
  330 |       await page.unroute(`**/api/forms/${formId}/settings`);
  331 |       await clickIfVisible(page.getByRole('button', { name: /bagikan & kode qr/i }));
  332 |       await expect(page.locator('body')).toContainText(/Bagikan Tautan|Tautan Publik|Kode QR/i);
  333 |       await clickIfVisible(page.getByRole('button', { name: /salin tautan/i }));
  334 |       await clickIfVisible(page.getByRole('button', { name: /pertanyaan & soal/i }));
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
```