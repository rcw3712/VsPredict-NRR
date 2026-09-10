# VsPredict PED Extension — Codex v2

Versi ini dibuat sebagai paket terpisah dan tidak menimpa `VsPredict_NRR_v5` atau run canonical lama.

## Tujuan

- menghitung ulang holdout Well-A 392/100 dengan Ridge stacker yang memakai meta-feature scaling secara konsisten;
- membentuk CNN window hanya di dalam segmen kedalaman kontinu;
- refit deployment fixed-HP pada Well-A dan menghasilkan prediksi seluruh enam model untuk 492 baris Well-B;
- menyelaraskan seluruh analisis dengan `ROW_ID`;
- menghitung paired moving-block bootstrap Ridge stacker versus Direct Ridge;
- menghitung physical-plausibility screen pada Pop-B 236 baris;
- memblokir freeze jika satu required gate gagal.

## Status ilmiah

Output diberi provenance:

```text
PED_CORRECTED_FIXED_HP_EXTENSION
```

Hyperparameter dibaca dari frozen deployment run lama. Karena itu, paket ini adalah targeted corrected extension, bukan pengganti diam-diam untuk full corrected nested-CV retuning. Historical holdout R² = −3.0622 dikarantina sebagai `LEGACY_INVALID_SCALING_MISMATCH`.

## Menjalankan self-test

```matlab
cd('C:\path\to\VsPredict_PED_Extension_Codex_v2')
addpath(genpath(pwd))
selftest_vspredict_ped_extension_codex
```

## Menjalankan pipeline

```matlab
cd('C:\path\to\VsPredict_PED_Extension_Codex_v2')
addpath(genpath(pwd))

summary = run_vspredict_ped_extension_codex( ...
    'C:\Drive E\VsPredict_NRR_v5', ...
    'run_20260903_155408');
```

Run baru ditulis ke:

```text
<project_root>\runs\ped_codex_<legacy_run_id>_<timestamp>
```

## Aturan penting

- Well-B tidak dipakai untuk fitting atau tuning.
- Pop-A diturunkan dari audit exact duplicates, bukan hard-coded mask.
- Pop-B bersifat target-informed dan hanya diagnostic.
- Full Well-B sensitivity tidak dihitung pada Condition A.
- Direct Ridge selalu `POST_HOC_SENSITIVITY`.
- Tidak ada fallback model.
- Tidak ada positional join.
- Error atau evidence yang tidak lengkap tidak pernah diubah menjadi PASS.

## Estimasi komputasi

Skrip melatih ulang neural networks untuk holdout dan corrected deployment pada CPU. Dengan 500 epochs sesuai config, proses dapat berlangsung lama. Jangan menghentikan MATLAB hanya karena output console tampak tenang; periksa Task Manager dan log run.

## Sebelum angka masuk manuskrip

1. Jalankan dua clean-session runs.
2. Bandingkan prediction vector, metric, masks, bootstrap summary, dan physical counts.
3. Lakukan full corrected nested-CV retuning terpisah jika hasil ini akan menggantikan canonical v5.
4. Regenerasi seluruh tabel dan gambar dari run corrected.
5. Pastikan figure QC mencapai 9/9 PASS.
