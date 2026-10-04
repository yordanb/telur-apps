import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/auth';
import { Btn } from './ui';

// Idle timeout: 30 mnt tanpa klik/ketik/sentuh/scroll → logout otomatis.
// 2 mnt sebelumnya muncul peringatan + tombol "Tetap masuk".
// Timestamp dibagi via localStorage agar multi-tab saling memperpanjang.
const TIMEOUT_MS = 30 * 60 * 1000;
const WARN_MS = 2 * 60 * 1000;
const LS_KEY = 'endog_last_activity';
const EVENTS = ['click', 'keydown', 'scroll', 'touchstart'] as const;

function readLast(): number {
  const v = Number(localStorage.getItem(LS_KEY));
  return Number.isFinite(v) && v > 0 ? v : Date.now();
}

export default function IdleGuard() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [warn, setWarn] = useState(false);
  const [remain, setRemain] = useState(WARN_MS / 1000);

  const doLogout = useCallback(() => {
    logout();
    setWarn(false);
    navigate('/login', { replace: true });
  }, [logout, navigate]);

  useEffect(() => {
    if (!user) {
      setWarn(false);
      return;
    }
    localStorage.setItem(LS_KEY, String(Date.now()));
    let lastWrite = 0;

    const onActivity = () => {
      const t = Date.now();
      if (t - lastWrite > 5000) {
        lastWrite = t;
        localStorage.setItem(LS_KEY, String(t));
      }
      setWarn(false);
    };
    EVENTS.forEach((e) => window.addEventListener(e, onActivity, { passive: true }));

    const tick = () => {
      const idle = Date.now() - readLast();
      if (idle >= TIMEOUT_MS) {
        doLogout();
      } else if (idle >= TIMEOUT_MS - WARN_MS) {
        setRemain(Math.max(1, Math.ceil((TIMEOUT_MS - idle) / 1000)));
        setWarn(true);
      } else {
        setWarn(false);
      }
    };
    tick();
    const id = window.setInterval(tick, 5000);
    return () => {
      EVENTS.forEach((e) => window.removeEventListener(e, onActivity));
      window.clearInterval(id);
    };
  }, [user, doLogout]);

  function stay() {
    localStorage.setItem(LS_KEY, String(Date.now()));
    setWarn(false);
  }

  if (!user || !warn) return null;

  const mm = Math.floor(remain / 60);
  const ss = String(remain % 60).padStart(2, '0');

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-sm rounded-2xl bg-white p-6 text-center shadow-xl">
        <p className="text-4xl">⏳</p>
        <h2 className="mt-2 text-lg font-bold text-gray-900">Sesi hampir berakhir</h2>
        <p className="mt-1 text-sm text-gray-600">
          Tidak ada aktivitas 28 menit. Anda keluar otomatis dalam{' '}
          <b className="text-red-600">{mm}:{ss}</b>.
        </p>
        <div className="mt-4 flex gap-2">
          <Btn kind="primary" className="flex-1" onClick={stay}>
            Tetap masuk
          </Btn>
          <Btn className="flex-1" onClick={doLogout}>
            Keluar
          </Btn>
        </div>
      </div>
    </div>
  );
}
