"""Helper jejak audit (activity log).

Dipakai endpoint auth/manajemen-user secara eksplisit dan middleware
tulis-data di main.py. Gagal mencatat tidak boleh menggagalkan request.
"""

from typing import Optional

from sqlalchemy.orm import Session

from app.models import ActivityLog


def client_ip(request) -> Optional[str]:
    xff = request.headers.get("x-forwarded-for")
    if xff:
        return xff.split(",")[0].strip()[:64]
    client = getattr(request, "client", None)
    if client and getattr(client, "host", None):
        return str(client.host)[:64]
    return None


def log_activity(
    db: Session,
    *,
    username: str,
    action: str,
    user_id: Optional[int] = None,
    detail: Optional[str] = None,
    ip: Optional[str] = None,
) -> None:
    try:
        db.add(
            ActivityLog(
                username=username,
                action=action,
                user_id=user_id,
                detail=detail,
                ip_address=ip,
            )
        )
        db.commit()
    except Exception:
        db.rollback()


_WRITE_SUFFIX = {"POST": "create", "PUT": "update", "PATCH": "update", "DELETE": "delete"}
# Auth & users dicatat eksplisit di routernya (butuh konteks: gagal login, target user).
_EXPLICIT_PREFIXES = ("/api/auth/", "/api/users/")


def describe_write(method: str, path: str) -> Optional[str]:
    """Ubah request tulis-data menjadi nama aksi audit, atau None jika
    tidak perlu dicatat (baca, auth/users eksplisit, di luar /api)."""
    suffix = _WRITE_SUFFIX.get(method)
    if not suffix or not path.startswith("/api/"):
        return None
    if path.startswith(_EXPLICIT_PREFIXES):
        return None
    resource = path[len("/api/"):].strip("/").split("/")[0]
    if not resource:
        return None
    return f"{resource}.{suffix}"
