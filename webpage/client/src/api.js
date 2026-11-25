// Fetch con el token de sesión (si existe) agregado como Authorization header.
// Si el servidor responde 401, la sesión ya no sirve (no hay token, o expiró):
// se limpia y se manda de vuelta al login con un aviso.
export async function apiFetch(path, options = {}) {
  const token = sessionStorage.getItem('token');
  const headers = { ...options.headers };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(path, { ...options, headers });

  if (res.status === 401) {
    logout({ expired: true });
  }

  return res;
}

export function logout({ expired = false } = {}) {
  sessionStorage.removeItem('token');
  sessionStorage.removeItem('usuario');
  window.location.href = `/api/nsx-autoservice/page/index${expired ? '?expired=1' : ''}`;
}

export function getUsuario() {
  try {
    return JSON.parse(sessionStorage.getItem('usuario'));
  } catch {
    return null;
  }
}
