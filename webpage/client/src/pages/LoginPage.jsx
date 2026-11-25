import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useTheme } from '../useTheme.js';

const shakeKeyframes = { x: [0, -10, 10, -8, 8, -4, 4, 0] };

export default function LoginPage() {
  useTheme();

  const [user, setUser] = useState('');
  const [password, setPassword] = useState('');
  const [status, setStatus] = useState('idle'); // idle | loading | success | error
  const [error, setError] = useState(
    new URLSearchParams(window.location.search).get('expired') ? 'Tu sesión expiró, ingresa de nuevo.' : ''
  );
  const [attempt, setAttempt] = useState(0);
  const [serverStatus, setServerStatus] = useState('checking'); // checking | online | offline

  useEffect(() => {
    fetch('/api/nsx-autoservice/page/')
      .then((res) => setServerStatus(res.ok ? 'online' : 'offline'))
      .catch(() => setServerStatus('offline'));
  }, []);

  const screenid = new URLSearchParams(window.location.search).get('id') || '';

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setStatus('loading');

    try {
      const res = await fetch('/api/nsx-autoservice/page/authentication', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user, password, screenid }),
      });
      const result = await res.json();

      if (result.success) {
        if (result.token) sessionStorage.setItem('token', result.token);
        if (result.usuario) sessionStorage.setItem('usuario', JSON.stringify(result.usuario));
        setStatus('success');
        setTimeout(() => {
          window.location.href = '/api/nsx-autoservice/page/home';
        }, 900);
      } else {
        setError(result.message || 'Credenciales inválidas');
        setStatus('error');
        setAttempt((n) => n + 1);
      }
    } catch {
      setError('Error al conectarse con el servidor');
      setStatus('error');
      setAttempt((n) => n + 1);
    }
  }

  const userTouched = user.length > 0;
  const passwordTouched = password.length > 0;
  const loading = status === 'loading';

  return (
    <div className="login-page">
      <motion.div
        className="login-card"
        initial={{ opacity: 0, y: 16 }}
        animate={status === 'error' ? { opacity: 1, y: 0, ...shakeKeyframes } : { opacity: 1, y: 0 }}
        key={attempt}
        transition={{ type: 'spring', stiffness: 300, damping: 24 }}
      >
        <AnimatePresence mode="wait">
          {status === 'success' ? (
            <motion.div
              key="success"
              className="login-success"
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ type: 'spring', stiffness: 260, damping: 20 }}
            >
              <motion.div
                className="success-check"
                initial={{ scale: 0, rotate: -45 }}
                animate={{ scale: 1, rotate: 0 }}
                transition={{ type: 'spring', stiffness: 300, damping: 18, delay: 0.1 }}
              >
                ✓
              </motion.div>
              <p className="login-title">Credenciales correctas</p>
              <p className="login-subtitle">Ingresando al panel...</p>
            </motion.div>
          ) : (
            <motion.form
              key="form"
              onSubmit={handleSubmit}
              noValidate
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
            >
              <motion.img
                className="login-logo"
                src={`${import.meta.env.BASE_URL}logo-insepet.png`}
                alt="INSEPET"
                initial={{ opacity: 0, scale: 0.85 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ type: 'spring', stiffness: 260, damping: 20, delay: 0.05 }}
              />
              <h1 className="login-title">Panel de operación</h1>
              <p className="login-subtitle">Ingresa con tu usuario y contraseña para gestionar el autoservicio</p>

              <motion.div
                className={`status-pill status-${serverStatus}`}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.15 }}
              >
                <span className="status-dot" />
                {serverStatus === 'checking' && 'Verificando sistema...'}
                {serverStatus === 'online' && 'Sistema en línea'}
                {serverStatus === 'offline' && 'Sin conexión al servidor'}
              </motion.div>

              <div className="field">
                <input
                  id="username"
                  type="text"
                  placeholder=" "
                  value={user}
                  onChange={(e) => setUser(e.target.value)}
                />
                <label htmlFor="username">Usuario</label>
                <AnimatePresence>
                  {userTouched && user.trim().length < 3 && (
                    <motion.span
                      className="field-hint"
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      exit={{ opacity: 0, height: 0 }}
                    >
                      Ingresa tu usuario completo
                    </motion.span>
                  )}
                </AnimatePresence>
              </div>

              <div className="field">
                <input
                  id="password"
                  type="password"
                  placeholder=" "
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
                <label htmlFor="password">Contraseña</label>
                <AnimatePresence>
                  {passwordTouched && password.length < 4 && (
                    <motion.span
                      className="field-hint"
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      exit={{ opacity: 0, height: 0 }}
                    >
                      La contraseña es muy corta
                    </motion.span>
                  )}
                </AnimatePresence>
              </div>

              <AnimatePresence>
                {error && (
                  <motion.p
                    className="login-error"
                    initial={{ opacity: 0, y: -6, height: 0 }}
                    animate={{ opacity: 1, y: 0, height: 'auto' }}
                    exit={{ opacity: 0, height: 0 }}
                  >
                    {error}
                  </motion.p>
                )}
              </AnimatePresence>

              <motion.button
                className="login-btn"
                type="submit"
                disabled={loading}
                whileHover={{ scale: loading ? 1 : 1.015 }}
                whileTap={{ scale: loading ? 1 : 0.97 }}
              >
                {loading ? <span className="spinner" /> : 'Ingresar'}
              </motion.button>

              <p className="login-footer">
                INSEPET · Grupo Empresarial
                <br />© {new Date().getFullYear()}
              </p>
            </motion.form>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  );
}
