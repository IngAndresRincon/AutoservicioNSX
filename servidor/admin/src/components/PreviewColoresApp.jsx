import { useState } from "react";

// Colores de respaldo de la app cuando no hay uno valido (los mismos de sus pantallas)
const FALLBACK = ["#1E88E5", "#2F80ED", "#56CCF2"];

const PANTALLAS = [
  { id: "identificacion", nombre: "Identificacion" },
  { id: "preset", nombre: "Preset" },
  { id: "pago", nombre: "Pago" },
  { id: "surtiendo", nombre: "Surtiendo" },
];

// El API guarda #AARRGGBB; el CSS lee #RRGGBB
function aCss(value, fallback) {
  const raw = String(value || "").trim().toUpperCase().replace("#", "");
  if (/^[0-9A-F]{8}$/.test(raw)) return `#${raw.slice(2)}`;
  if (/^[0-9A-F]{6}$/.test(raw)) return `#${raw}`;
  return fallback;
}

function canales(hex) {
  return [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
}

// Luminancia relativa, igual que computeLuminance() de Flutter
function luminancia(hex) {
  const [r, g, b] = canales(hex).map((v) => {
    const c = v / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

// Misma regla de la app (color_utils.dart): fondo claro -> texto oscuro, si no blanco
function textoSobre(hex) {
  return luminancia(hex) > 0.4 ? "#1A1A1A" : "#FFFFFF";
}

function mezcla(a, b) {
  const ca = canales(a);
  const cb = canales(b);
  const mid = ca.map((v, i) => Math.round((v + cb[i]) / 2));
  return `#${mid.map((v) => v.toString(16).padStart(2, "0")).join("")}`;
}

function contraste(fondo, texto) {
  const l1 = luminancia(fondo);
  const l2 = luminancia(texto);
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
}

function avisos(principal, secundario, acento) {
  const lista = [];
  const degradado = mezcla(acento, secundario);
  const textoBoton = textoSobre(degradado);

  if (contraste(degradado, textoBoton) < 3) {
    lista.push("El texto de los botones (degradado acento-secundario) queda con poco contraste.");
  }
  if (luminancia(principal) > 0.5) {
    lista.push("El principal es muy claro: el encabezado de Identificacion lleva texto blanco y no se leera bien.");
  }
  return lista;
}

function Teclado({ teclas }) {
  return (
    <div className="clv-keypad">
      {teclas.map((tecla) => (
        <span key={tecla} className="clv-key">
          {tecla}
        </span>
      ))}
    </div>
  );
}

function Identificacion() {
  return (
    <div className="clv-screen clv-ident">
      <div className="clv-header">
        <span className="clv-back">‹</span>
        <strong className="clv-logo">LOGO</strong>
        <span className="clv-chip">Codigo</span>
      </div>
      <div className="clv-sheet">
        <div className="clv-col">
          <p className="clv-title">Ingrese su documento</p>
          <div className="clv-display">1234567890</div>
          <span className="clv-btn">Confirmar</span>
          <p className="clv-habeas">
            Al continuar, acepta el <u className="clv-link">tratamiento de sus datos personales</u>.
          </p>
        </div>
        <Teclado teclas={["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]} />
      </div>
    </div>
  );
}

function Preset() {
  return (
    <div className="clv-screen clv-soft">
      <div className="clv-bar">
        <span className="clv-back clv-back-dark">‹</span>
        <strong className="clv-bar-title">GASOLINA CORRIENTE</strong>
        <span className="clv-price">$15.690</span>
      </div>
      <div className="clv-body">
        <div className="clv-toggle">
          <span className="clv-toggle-on">Dinero</span>
          <span>Volumen</span>
        </div>
        <div className="clv-input">$ 20.000</div>
        <div className="clv-chips">
          <span className="clv-pill clv-pill-on">$10.000</span>
          <span className="clv-pill">$20.000</span>
          <span className="clv-pill">$50.000</span>
          <span className="clv-pill">Lleno</span>
        </div>
        <span className="clv-btn">Continuar</span>
      </div>
    </div>
  );
}

function Pago() {
  return (
    <div className="clv-screen clv-soft">
      <div className="clv-bar">
        <span className="clv-back clv-back-dark">‹</span>
        <strong className="clv-bar-title">Forma de pago</strong>
      </div>
      <div className="clv-body">
        <div className="clv-total">
          <span>Total a pagar</span>
          <strong>$20.000</strong>
        </div>
        <div className="clv-methods">
          <span className="clv-method clv-method-on">Datafono</span>
          <span className="clv-method">Nequi</span>
          <span className="clv-method">QR Vueltos</span>
        </div>
        <span className="clv-btn">Pagar</span>
      </div>
    </div>
  );
}

function Surtiendo() {
  return (
    <div className="clv-screen clv-dark">
      <div className="clv-ring" />
      <p className="clv-dark-title">Surtiendo...</p>
      <p className="clv-dark-number">$ 12.340</p>
      <p className="clv-dark-sub">0,786 galones</p>
      <span className="clv-btn clv-btn-small">Finalizar</span>
    </div>
  );
}

const VISTAS = { identificacion: Identificacion, preset: Preset, pago: Pago, surtiendo: Surtiendo };

export default function PreviewColoresApp({ colors, pantallaInicial = "identificacion", verticalInicial = false }) {
  const [pantalla, setPantalla] = useState(pantallaInicial);
  const [vertical, setVertical] = useState(verticalInicial);

  const principal = aCss(colors[0], FALLBACK[0]);
  const secundario = aCss(colors[1], FALLBACK[1]);
  const acento = aCss(colors[2], FALLBACK[2]);
  const textoBoton = textoSobre(mezcla(acento, secundario));
  const alertas = avisos(principal, secundario, acento);
  const Vista = VISTAS[pantalla];

  return (
    <section className="clv-card">
      <div className="clv-top">
        <div>
          <p className="clv-eyebrow">Vista previa</p>
          <h4 className="clv-heading">Asi se vera la app con estos colores</h4>
        </div>
        <div className="clv-controls">
          <div className="clv-tabs">
            {PANTALLAS.map((item) => (
              <button
                key={item.id}
                type="button"
                className={pantalla === item.id ? "is-on" : ""}
                onClick={() => setPantalla(item.id)}
              >
                {item.nombre}
              </button>
            ))}
          </div>
          <button type="button" className="clv-orient" onClick={() => setVertical((v) => !v)}>
            {vertical ? "Vertical" : "Horizontal"}
          </button>
        </div>
      </div>

      <div className="clv-stage">
        <div
          className={`clv-frame${vertical ? " is-vertical" : ""}`}
          style={{
            "--c1": principal,
            "--c2": secundario,
            "--c3": acento,
            "--on-grad": textoBoton,
          }}
        >
          <Vista />
        </div>
      </div>

      <div className="clv-legend">
        <span><i style={{ background: principal }} /> Principal: fondo de Identificacion, bordes, iconos y enlaces</span>
        <span><i style={{ background: secundario }} /> Secundario: final del degradado y sombra de los botones</span>
        <span><i style={{ background: acento }} /> Tercero: inicio del degradado de los botones</span>
      </div>

      {alertas.length > 0 && (
        <ul className="clv-warnings">
          {alertas.map((texto) => (
            <li key={texto}>{texto}</li>
          ))}
        </ul>
      )}
    </section>
  );
}
