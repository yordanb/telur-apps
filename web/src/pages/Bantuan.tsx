import { useState } from 'react';
import { useAuth } from '../lib/auth';
import { Modal, PageHead } from '../components/ui';

interface Section {
  icon: string;
  title: string;
  desc: string;
  roles?: string;
  points: string[];
}

const SECTIONS: Section[] = [
  {
    icon: '🏠', title: 'Dashboard',
    desc: 'Ringkasan 30 hari, grafik & tabel cepat',
    points: [
      'Ringkasan 30 hari terakhir: total telur, pendapatan, biaya pakan, biaya lain, dan perkiraan laba kotor.',
      'Grafik 14 hari terakhir + tabel 7 hari dan bulanan tahun berjalan.',
      'Klik "Lihat statistik lengkap" untuk filter tanggal bebas.',
    ],
  },
  {
    icon: '📊', title: 'Statistik',
    desc: 'Tren harian & rekap bulanan + filter',
    points: [
      'Tabel harian (telur, baik, rusak, biaya pakan/lain, pendapatan) + total, dan tabel bulanan (termasuk kas masuk/keluar).',
      'Atur rentang tanggal dan tahun, lalu tekan Tampilkan.',
      'Data mengikuti hak lihat: pegawai hanya data miliknya, admin/investor semua data.',
    ],
  },
  {
    icon: '🥚', title: 'Produksi Telur',
    desc: 'Catat hasil harian + rincian per ayam',
    roles: 'Tulis: admin + pegawai. Investor baca saja.',
    points: [
      'Catat hasil harian: total, baik, rusak, berat rata-rata (opsional), catatan.',
      'Rincian per ayam opsional: jika diisi, Total & Baik OTOMATIS = jumlah rincian (aturan server). Satu ayam 1× per catatan.',
      'Ubah: kirim ulang rincian untuk mengganti total; Hapus: konfirmasi dulu.',
    ],
  },
  {
    icon: '🐔', title: 'Ayam',
    desc: 'Register bersama, foto & agregat harian',
    roles: 'Lihat: semua role. Tulis: admin + pegawai. Hapus: pemilik/admin.',
    points: [
      'Register: ayam adalah ASET KANDANG BERSAMA — terlihat semua user. Kode unik global; status: aktif/sakit/mati/terjual.',
      'Foto: tombol Foto per kartu (JPG/PNG/WebP ≤5MB); mengganti foto lama otomatis.',
      'Agregat harian: rekap jumlah total/sehat/sakit/mati/baru per tanggal (milik masing-masing user).',
    ],
  },
  {
    icon: '🌾', title: 'Pakan',
    desc: 'Stok global & riwayat pemberian',
    roles: 'Tulis: admin + pegawai. Investor baca saja.',
    points: [
      'Kartu stok = pembelian (menu Biaya kategori pakan) − pemberian. Global satu kandang, terlihat semua role.',
      'Jumlah pemberian TIDAK BOLEH melebihi sisa (server menolak 400 + pesan sisa).',
      'Pemberian pakan tidak menyentuh kas — hanya mengatur stok.',
    ],
  },
  {
    icon: '🧾', title: 'Biaya',
    desc: 'Pembelian pakan (kg), obat & operasional',
    roles: 'Tulis: admin + pegawai (milik sendiri). Investor baca semua.',
    points: [
      'Kategori pakan = pembelian: wajib jenis + kg + harga/kg; total OTOMATIS = kg × harga, sekaligus menambah stok.',
      'Kategori operasional: wajib subkategori (Perbaikan/Perawatan/Pembuatan kandang).',
      'Kategori obat/lainnya: deskripsi + jumlah rupiah.',
    ],
  },
  {
    icon: '💰', title: 'Penjualan Telur',
    desc: 'Butir/kg, total dihitung server',
    roles: 'Tulis: admin + pegawai. Investor baca saja.',
    points: [
      'Satuan butir atau kg; isi jumlah + harga per satuan.',
      'Total OTOMATIS dihitung server (jumlah × harga).',
    ],
  },
  {
    icon: '👛', title: 'Kas Manual',
    desc: 'Arus kas di luar penjualan & biaya',
    roles: 'Tulis: admin + pegawai. Investor baca saja.',
    points: [
      'Arah masuk (cth: Penjualan ayam afkir, Setoran modal) atau keluar; jumlah harus > 0.',
      'Kas di luar Biaya: jangan catat pembelian pakan/operasional di sini (sudah di Biaya).',
    ],
  },
  {
    icon: '💳', title: 'Keuangan',
    desc: 'Neraca arus kas + rincian kategori',
    points: [
      'Pemasukan = penjualan telur + kas masuk. Pengeluaran = SEMUA Biaya + kas keluar.',
      'Pilih periode 7/30/90 hari atau Semua (periode panjang diagregat per bulan di grafik).',
      'Maksimal 1000 baris per sumber ditarik; cukup untuk skala saat ini.',
    ],
  },
  {
    icon: '🏆', title: 'Produktivitas Ayam',
    desc: 'Laying rate per ekor & peringkat',
    points: [
      'Laying rate per ekor = total butir ÷ hari-hadir × 100%.',
      'Hari-hadir = dari maks(awal periode, tanggal masuk ayam) sampai hari ini.',
      'Butuh rincian per ayam di Produksi agar per-ekor terhitung; peringkat hanya ayam aktif.',
    ],
  },
  {
    icon: '👥', title: 'Pengguna',
    desc: 'Kelola akun & role',
    roles: 'KHUSUS ADMIN.',
    points: [
      'Tambah user: username, email, nama, password, role (admin/pegawai/investor).',
      'Register publik hanya menghasilkan pegawai — admin/investor dibuat di sini.',
      'Tidak bisa menghapus akun sendiri.',
    ],
  },
  {
    icon: '📋', title: 'Log Aktivitas',
    desc: 'Audit login, gagal & tulis-data',
    roles: 'KHUSUS ADMIN.',
    points: [
      'Mencatat login (termasuk GAGAL + username yang dicoba), logout, register, ganti password, CRUD user, dan semua tulis-data modul.',
      'Filter tanggal/aksi/username + Muat lagi. Login gagal berbadge merah.',
      'Tulis tanpa token valid tidak dicatat (menghindari noise).',
    ],
  },
  {
    icon: '⚙️', title: 'Pengaturan',
    desc: 'Profil, password & warna tema',
    points: [
      'Ubah nama & email sendiri (username & role tidak bisa diubah).',
      'Ganti password: wajib tahu password lama, min. 6 karakter.',
      'Warna tema (Oranye/Hijau/Biru) tersimpan di profil — ikut pindah device. Sidebar mini (ikon saja) tersimpan per browser.',
    ],
  },
];

export default function Bantuan() {
  const { user } = useAuth();
  const [open, setOpen] = useState<Section | null>(null);
  const isInvestor = user?.role === 'investor';

  return (
    <div className="mx-auto max-w-5xl space-y-4">
      <PageHead title="📖 Bantuan Penggunaan" />
      <div className="rounded-2xl bg-brand-100 p-4 text-sm text-brand-800">
        <b>Hak akses Anda: {user?.role}</b>
        {isInvestor
          ? ' — read-only: Anda bisa melihat semua data, tombol Tambah/Ubah/Hapus disembunyikan.'
          : user?.role === 'pegawai'
            ? ' — tulis data milik sendiri; data Biaya/Kas difilter milik Anda.'
            : ' — akses penuh termasuk Pengguna & Log Aktivitas.'}
      </div>

      {/* Grid tile ala Fiori launchpad */}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {SECTIONS.map((s) => (
          <button
            key={s.title}
            onClick={() => setOpen(s)}
            className="group rounded-2xl bg-white p-5 text-left shadow transition hover:-translate-y-0.5 hover:shadow-lg"
          >
            <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand-100 text-2xl transition group-hover:bg-brand-200">
              {s.icon}
            </span>
            <p className="mt-3 font-bold text-gray-900">{s.title}</p>
            <p className="mt-0.5 text-sm text-gray-500">{s.desc}</p>
            <p className="mt-2 text-xs font-medium text-brand-700">
              {s.roles ?? 'Semua role'} →
            </p>
          </button>
        ))}
      </div>
      <p className="text-center text-xs text-gray-400">
        Klik tile untuk panduan lengkap. Filter tanggal "Sampai" mencakup seharian penuh.
      </p>

      {open && (
        <Modal title={`${open.icon} ${open.title}`} onClose={() => setOpen(null)}>
          <div className="space-y-3">
            {open.roles && (
              <p className="rounded-lg bg-gray-100 px-3 py-1.5 text-xs font-medium text-gray-700">
                {open.roles}
              </p>
            )}
            <ul className="list-disc space-y-1.5 pl-5 text-sm text-gray-600">
              {open.points.map((p, i) => (
                <li key={i}>{p}</li>
              ))}
            </ul>
          </div>
        </Modal>
      )}
    </div>
  );
}
