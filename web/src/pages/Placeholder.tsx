export default function Placeholder({ title }: { title: string }) {
  return (
    <div className="rounded-2xl bg-white p-8 shadow">
      <h1 className="text-2xl font-bold text-gray-900">{title}</h1>
      <p className="mt-2 text-sm text-gray-600">
        Modul ini segera hadir — dikerjakan di milestone berikutnya.
      </p>
    </div>
  );
}
