import { useEffect, useState } from "react";
import api from "../services/api";

const QUICK_STATS = [
  { value: "Mapeo", label: "control visual de pista" },
  { value: "Media", label: "contenidos por isla" },
  { value: "Panel", label: "gestion operativa central" },
];

export default function Login() {
  const [userName, setUserName] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [sistema, setSistema] = useState("NSX");

  useEffect(() => {
    let cancelado = false;

    api
      .get("/Admin/ObtenerMapeoConfiguracion")
      .then((res) => {
        const petrolera = res.data?.data?.estacion?.bandera?.petrolera;
        if (!cancelado && petrolera) {
          setSistema(petrolera);
        }
      })
      .catch(() => {});

    return () => {
      cancelado = true;
    };
  }, []);

  const login = async () => {
    if (!userName || !password) {
      setError("Completa todos los campos.");
      return;
    }

    setLoading(true);
    setError("");

    try {
      const res = await api.post("/Admin/Login", { userName, password });
      if (res.data.success) {
        localStorage.setItem("auth", "true");
        localStorage.setItem("user", JSON.stringify(res.data.data));
        localStorage.setItem("lastActivity", String(Date.now()));
        window.location.href = "/";
      } else {
        setError("Credenciales incorrectas.");
      }
    } catch {
      setError("Credenciales incorrectas.");
    } finally {
      setLoading(false);
    }
  };

  const onKey = (e) => e.key === "Enter" && login();

  return (
    <div style={s.page}>
      <div style={s.bgMesh} aria-hidden />
      <div style={s.bgGlowOne} aria-hidden />
      <div style={s.bgGlowTwo} aria-hidden />

      <div style={s.shell}>
        <section style={s.showcase}>
          <span style={s.kicker}>Portal dinamico</span>
          <h1 style={s.title}>Autoservicio {sistema}</h1>
          <p style={s.copy}>
            Un acceso central para operar estaciones, revisar configuraciones y
            mantener la experiencia de autoservicio con mejor visibilidad.
          </p>

          <div style={s.featurePanel}>
            <div style={s.featureHeader}>
              <span style={s.liveDot} />
              <p style={s.featureTag}>Vista operativa</p>
            </div>

            <div style={s.featureGrid}>
              {QUICK_STATS.map((item) => (
                <div key={item.value} style={s.featureCard}>
                  <p style={s.featureValue}>{item.value}</p>
                  <p style={s.featureLabel}>{item.label}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section style={s.loginPanel}>
          <div style={s.loginCard}>
            <div style={s.logoMarkRow}>
              <div style={s.logoMark}>
                <img src="/logo-nsx.png" alt="Logo NSX" style={s.logoMarkImg} />
              </div>
              <div style={s.logoMarkWide}>
                <img
                  src="/logo-insepet.png"
                  alt="Logo Insepet"
                  style={s.logoMarkImgWide}
                />
              </div>
            </div>
            <h2 style={s.heading}>Ingresar al portal</h2>
            <p style={s.sub}>Accede al panel administrativo con tus credenciales.</p>

            <div style={s.fields}>
              <div style={s.field}>
                <label style={s.label}>Usuario</label>
                <input
                  style={s.input}
                  placeholder="nombre.apellido"
                  value={userName}
                  onChange={(e) => setUserName(e.target.value)}
                  onKeyDown={onKey}
                  autoComplete="username"
                />
              </div>

              <div style={s.field}>
                <label style={s.label}>Contrasena</label>
                <input
                  style={s.input}
                  type="password"
                  placeholder="Ingresa tu clave"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onKeyDown={onKey}
                  autoComplete="current-password"
                />
              </div>
            </div>

            {error && <p style={s.error}>{error}</p>}

            <button
              style={{ ...s.btn, opacity: loading ? 0.7 : 1 }}
              onClick={login}
              disabled={loading}
            >
              {loading ? "Verificando..." : "Entrar al panel"}
            </button>

            <p style={s.footer}>Panel administrativo de autoservicio</p>
          </div>
        </section>
      </div>
    </div>
  );
}

const s = {
  page: {
    minHeight: "100vh",
    position: "relative",
    overflow: "hidden",
    background:
      "linear-gradient(135deg, #081221 0%, #11294a 48%, #1b4a86 100%)",
    display: "grid",
    placeItems: "center",
    padding: 20,
  },
  bgMesh: {
    position: "absolute",
    inset: 0,
    backgroundImage:
      "linear-gradient(rgba(255,255,255,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.06) 1px, transparent 1px)",
    backgroundSize: "48px 48px",
    maskImage: "linear-gradient(180deg, rgba(0,0,0,0.55), rgba(0,0,0,0.15))",
  },
  bgGlowOne: {
    position: "absolute",
    width: 460,
    height: 460,
    borderRadius: "50%",
    background: "rgba(72, 153, 255, 0.18)",
    top: -140,
    left: -120,
    filter: "blur(18px)",
  },
  bgGlowTwo: {
    position: "absolute",
    width: 360,
    height: 360,
    borderRadius: "50%",
    background: "rgba(255, 167, 76, 0.18)",
    right: -80,
    bottom: -100,
    filter: "blur(24px)",
  },
  shell: {
    position: "relative",
    zIndex: 1,
    width: "min(1180px, 100%)",
    display: "grid",
    gridTemplateColumns: "minmax(0, 1.05fr) minmax(360px, 420px)",
    borderRadius: 30,
    overflow: "hidden",
    border: "1px solid rgba(255,255,255,0.16)",
    boxShadow: "0 28px 70px rgba(3, 10, 23, 0.35)",
    background: "rgba(6, 18, 36, 0.28)",
    backdropFilter: "blur(18px)",
  },
  showcase: {
    padding: "56px 52px",
    color: "#fff",
    display: "flex",
    flexDirection: "column",
    justifyContent: "space-between",
    gap: 28,
    minHeight: 620,
  },
  kicker: {
    display: "inline-flex",
    alignSelf: "flex-start",
    padding: "8px 12px",
    borderRadius: 999,
    background: "rgba(255,255,255,0.08)",
    border: "1px solid rgba(255,255,255,0.14)",
    fontSize: 11,
    textTransform: "uppercase",
    letterSpacing: "0.14em",
    color: "rgba(230,239,255,0.88)",
  },
  title: {
    fontSize: 60,
    lineHeight: 0.95,
    maxWidth: 520,
    color: "#fff",
    marginTop: 10,
  },
  copy: {
    maxWidth: 520,
    fontSize: 16,
    lineHeight: 1.75,
    color: "rgba(225,236,255,0.82)",
  },
  featurePanel: {
    marginTop: "auto",
    borderRadius: 26,
    padding: 22,
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.12) 0%, rgba(255,255,255,0.06) 100%)",
    border: "1px solid rgba(255,255,255,0.12)",
  },
  featureHeader: {
    display: "flex",
    alignItems: "center",
    gap: 10,
    marginBottom: 18,
  },
  liveDot: {
    width: 10,
    height: 10,
    borderRadius: "50%",
    background: "#65d39a",
    boxShadow: "0 0 0 6px rgba(101,211,154,0.12)",
  },
  featureTag: {
    fontSize: 12,
    textTransform: "uppercase",
    letterSpacing: "0.12em",
    color: "rgba(235,242,255,0.8)",
  },
  featureGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
    gap: 14,
  },
  featureCard: {
    padding: "16px 14px",
    borderRadius: 18,
    background: "rgba(5, 14, 28, 0.24)",
    border: "1px solid rgba(255,255,255,0.1)",
  },
  featureValue: {
    fontSize: 18,
    fontWeight: 700,
    color: "#fff",
    marginBottom: 8,
  },
  featureLabel: {
    fontSize: 12,
    lineHeight: 1.55,
    color: "rgba(225,236,255,0.78)",
  },
  loginPanel: {
    background: "rgba(244, 247, 251, 0.94)",
    display: "grid",
    placeItems: "center",
    padding: 26,
  },
  loginCard: {
    width: "100%",
    borderRadius: 28,
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.95) 0%, rgba(248,250,252,0.98) 100%)",
    border: "1px solid rgba(22, 43, 73, 0.08)",
    padding: "34px 30px",
    boxShadow: "0 20px 40px rgba(22, 43, 73, 0.08)",
  },
  logoMarkRow: {
    display: "flex",
    gap: 10,
    marginBottom: 20,
  },
  logoMark: {
    width: 52,
    height: 52,
    borderRadius: 16,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background:
      "linear-gradient(135deg, rgba(15,32,61,0.95) 0%, rgba(27,74,138,0.95) 100%)",
    boxShadow: "0 12px 24px rgba(15,32,61,0.22)",
  },
  logoMarkImg: {
    width: "72%",
    height: "72%",
    objectFit: "contain",
  },
  logoMarkWide: {
    width: 100,
    height: 52,
    borderRadius: 16,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background:
      "linear-gradient(135deg, rgba(15,32,61,0.95) 0%, rgba(27,74,138,0.95) 100%)",
    boxShadow: "0 12px 24px rgba(15,32,61,0.22)",
    padding: "0 8px",
  },
  logoMarkImgWide: {
    width: "100%",
    height: "82%",
    objectFit: "contain",
  },
  heading: {
    fontSize: 30,
    color: "var(--text-primary)",
    marginBottom: 8,
  },
  sub: {
    color: "var(--text-secondary)",
    fontSize: 14,
    lineHeight: 1.65,
    marginBottom: 26,
  },
  fields: {
    display: "grid",
    gap: 16,
  },
  field: {
    display: "grid",
    gap: 7,
  },
  label: {
    fontSize: 12,
    fontWeight: 700,
    color: "var(--text-secondary)",
    textTransform: "uppercase",
    letterSpacing: "0.08em",
  },
  input: {
    width: "100%",
    padding: "14px 15px",
    borderRadius: 16,
    border: "1px solid var(--border-strong)",
    background: "rgba(244,247,251,0.95)",
    color: "var(--text-primary)",
    fontSize: 14,
    outline: "none",
  },
  error: {
    marginTop: 14,
    padding: "11px 13px",
    borderRadius: 14,
    background: "rgba(217, 64, 64, 0.08)",
    color: "var(--danger)",
    border: "1px solid rgba(217, 64, 64, 0.16)",
    fontSize: 13,
  },
  btn: {
    width: "100%",
    marginTop: 20,
    padding: "14px 16px",
    border: "none",
    borderRadius: 16,
    background:
      "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
    color: "#fff",
    fontSize: 14,
    fontWeight: 700,
    cursor: "pointer",
    boxShadow: "0 18px 28px rgba(41,112,255,0.22)",
  },
  footer: {
    marginTop: 18,
    fontSize: 12,
    textAlign: "center",
    color: "var(--text-muted)",
  },
};
