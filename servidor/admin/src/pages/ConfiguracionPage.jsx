import { useCallback, useEffect, useState } from "react";
import { usePortalFeedback } from "../components/portalFeedbackContext";
import api from "../services/api";

function plural(n, singular, pluralTexto) {
  return `${n} ${n === 1 ? singular : pluralTexto}`;
}

function Pill({ children, tone = "neutral" }) {
  const tones = {
    neutral: {
      background: "rgba(18,31,53,0.06)",
      color: "var(--text-secondary)",
      border: "1px solid rgba(18,31,53,0.08)",
    },
    blue: {
      background: "rgba(41,112,255,0.1)",
      color: "var(--accent-strong)",
      border: "1px solid rgba(41,112,255,0.12)",
    },
    green: {
      background: "rgba(36,118,86,0.12)",
      color: "var(--success-strong)",
      border: "1px solid rgba(36,118,86,0.12)",
    },
    amber: {
      background: "rgba(222,139,28,0.12)",
      color: "var(--amber)",
      border: "1px solid rgba(222,139,28,0.14)",
    },
  };

  return <span style={{ ...styles.pill, ...tones[tone] }}>{children}</span>;
}

export default function ConfiguracionPage() {
  const portalFeedback = usePortalFeedback();
  const [mapeo, setMapeo] = useState(null);
  const [catalogos, setCatalogos] = useState(null);
  const [dispositivos, setDispositivos] = useState([]);
  const [deviceDrafts, setDeviceDrafts] = useState({});
  const [deviceEditing, setDeviceEditing] = useState({});
  const [screenDrafts, setScreenDrafts] = useState({});
  const [hoseDrafts, setHoseDrafts] = useState({});
  const [productDrafts, setProductDrafts] = useState({});
  const [paymentDrafts, setPaymentDrafts] = useState({});
  const [systemDraft, setSystemDraft] = useState(null);
  const [marcacionesDraft, setMarcacionesDraft] = useState(null);
  const [fidelidad, setFidelidad] = useState([]);
  const [formasVendedor, setFormasVendedor] = useState([]);
  const [activeSection, setActiveSection] = useState("sistema");
  const [selectedDispensador, setSelectedDispensador] = useState("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const hydrateDrafts = useCallback((mapeoData, dispositivosData, catalogosData) => {
    setDeviceDrafts((current) => {
      const next = { ...current };
      for (const item of dispositivosData) {
        if (next[item.idDispensador] === undefined) {
          next[item.idDispensador] = {
            idDispositivo: item.idDispositivo ?? 0,
            idDispensador: item.idDispensador,
            identificador: item.identificador || "",
            ip: item.ip || "",
            activo: item.activo ?? true,
            modoHibrido: item.modoHibrido ?? false,
            tiempoReal: item.tiempoReal ?? false,
            intervaloTiempoReal: item.intervaloTiempoReal ?? 500,
            identificadoresCliente: item.identificadoresCliente || "1|1|1",
          };
        }
      }
      for (const dispensador of mapeoData?.dispensadores ?? []) {
        if (next[dispensador.idDispensador] === undefined) {
          next[dispensador.idDispensador] = {
            idDispositivo: 0,
            idDispensador: dispensador.idDispensador,
            identificador: "",
            ip: "",
            activo: true,
            modoHibrido: false,
            tiempoReal: false,
            intervaloTiempoReal: 500,
            identificadoresCliente: "1|1|1",
          };
        }
      }
      return next;
    });

    setScreenDrafts((current) => {
      const next = { ...current };
      for (const dispensador of mapeoData?.dispensadores ?? []) {
        for (const cara of dispensador.caras ?? []) {
          const firstPosition = cara.posiciones?.[0];
          if (!firstPosition) continue;
          const key = getScreenKey(firstPosition.idPosicion);
          if (!next[key]) {
            next[key] = {
              idPosicion: firstPosition.idPosicion,
              serialPantalla: cara.serialPantalla || "",
              codigoTankio: firstPosition.codigoTankio || "",
            };
          }
        }
      }
      return next;
    });

    setHoseDrafts((current) => {
      const next = { ...current };
      for (const dispensador of mapeoData?.dispensadores ?? []) {
        for (const cara of dispensador.caras ?? []) {
          for (const posicion of cara.posiciones ?? []) {
            for (const manguera of posicion.mangueras ?? []) {
              const key = getHoseKey(manguera.idPosicionGrado);
              if (!next[key]) {
                next[key] = {
                  idPosicionGrado: manguera.idPosicionGrado,
                  lado: manguera.lado || "",
                  color: manguera.color || "",
                };
              }
            }
          }
        }
      }
      return next;
    });
    setProductDrafts((current) => {
      const next = { ...current };
      for (const producto of catalogosData?.productos ?? []) {
        if (next[producto.idProducto] === undefined) {
          next[producto.idProducto] = producto.maximoPreset ?? 0;
        }
      }
      return next;
    });

    setPaymentDrafts((current) => {
      const next = { ...current };
      for (const formaPago of catalogosData?.formasPagoAuto ?? []) {
        if (!next[formaPago.idFormaPago]) {
          next[formaPago.idFormaPago] = {
            idFormaPagoAuto: formaPago.idFormaPago,
            idFormaPago: formaPago.idFormaPagoSistema ?? 0,
            descripcion: formaPago.nombre || "",
            activo: formaPago.activo ?? true,
          };
        }
      }
      return next;
    });

    setSystemDraft((current) => {
      if (current) return current;
      return {
        sistema: mapeoData?.estacion?.bandera?.petrolera || "GNESYS",
        maxVueltos: mapeoData?.estacion?.maximoVueltos ?? 0,
      };
    });

    setMarcacionesDraft((current) => {
      if (current) return current;
      const marcaciones = mapeoData?.estacion?.marcacionesRapidas;
      return {
        dinero: padMarcaciones(marcaciones?.dinero),
        volumen: padMarcaciones(marcaciones?.volumen),
      };
    });
  }, []);

  const cargarConfiguracion = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const [mapeoRes, dispositivosRes, catalogosRes, fidelidadRes, formasVendedorRes] = await Promise.all([
        api.get("/Admin/ObtenerMapeoConfiguracion"),
        api.get("/Admin/ObtenerDispositivos"),
        api.get("/Admin/ObtenerCatalogos"),
        // Si el servicio aun no tiene este endpoint, el resto de la pagina sigue funcionando
        api.get("/Admin/ObtenerFidelidad").catch(() => null),
        api.get("/Admin/ObtenerFormasPagoVendedor").catch(() => null),
      ]);

      const mapeoData = mapeoRes.data?.data ?? null;
      const dispositivosData = dispositivosRes.data?.data ?? [];
      const catalogosData = catalogosRes.data?.data ?? null;

      setMapeo(mapeoData);
      setCatalogos(catalogosData);
      setDispositivos(dispositivosData);
      setFidelidad(fidelidadRes?.data?.data ?? []);
      setFormasVendedor(formasVendedorRes?.data?.data ?? []);
      hydrateDrafts(mapeoData, dispositivosData, catalogosData);
    } catch {
      setError("No fue posible cargar la configuracion inicial.");
    } finally {
      setLoading(false);
    }
  }, [hydrateDrafts]);

  async function guardarDispositivo(idDispensador) {
    const draft = deviceDrafts[idDispensador] || {};
    const ip = (draft.ip || "").trim();

    if (!(draft.identificador || "").trim()) {
      portalFeedback.toastError(
        `Debes ingresar un identificador para el dispensador ${idDispensador}.`
      );
      return;
    }

    const identificador = (draft.identificador || "")
      .replace(/[^a-zA-Z0-9]/g, "")
      .toUpperCase();

    if (identificador.length !== 12) {
      portalFeedback.toastError(
        `El identificador del dispensador ${idDispensador} debe tener 12 caracteres (MAC sin separadores, ej. 147D62C3B444).`
      );
      return;
    }

    if (!ip) {
      portalFeedback.toastError(
        `Debes ingresar la IP para el dispensador ${idDispensador}.`
      );
      return;
    }

    const intervalo = Number(draft.intervaloTiempoReal) || 500;
    if (draft.tiempoReal && (!Number.isInteger(intervalo) || intervalo < 200 || intervalo > 5000)) {
      portalFeedback.toastError("El tiempo real se actualiza entre 200 y 5000 ms.");
      return;
    }

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/GuardarDispositivos", [
            {
              idDispositivo: draft.idDispositivo || 0,
              idDispensador,
              identificador,
              ip,
              activo: Boolean(draft.activo ?? true),
              modoHibrido: Boolean(draft.modoHibrido ?? false),
              tiempoReal: Boolean(draft.tiempoReal ?? false),
              intervaloTiempoReal: Math.min(5000, Math.max(200, Math.round(intervalo))),
              identificadoresCliente: draft.identificadoresCliente || "1|1|1",
            },
          ]);

          if (response.data?.success === false) {
            const errores = response.data?.errors;
            throw new Error(
              (Array.isArray(errores) && errores.filter(Boolean).join(" ")) ||
                response.data?.message ||
                "No fue posible guardar el dispositivo."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando dispositivo",
            message: `Estamos actualizando el equipo atado al dispensador ${idDispensador}.`,
          },
          successMessage: `El dispositivo del dispensador ${idDispensador} quedo actualizado.`,
          errorMessage: "No fue posible guardar el dispositivo.",
        }
      );

      await cargarConfiguracion();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  async function guardarPantalla(screenState) {
    const serialPantalla = (screenState.serialPantalla || "").trim();
    const codigoTankio = (screenState.codigoTankio || "").trim();

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/GuardarPantallas", [
            {
              idPosicion: screenState.idPosicion,
              serialPantalla,
              codigoTankio,
            },
          ]);

          if (response.data?.success === false) {
            throw new Error(
              response.data?.message || "No fue posible guardar la pantalla."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando pantalla",
            message: `Estamos actualizando la configuracion de la posicion ${screenState.idPosicion}.`,
          },
          successMessage: `La configuracion de la posicion ${screenState.idPosicion} quedo guardada.`,
          errorMessage: "No fue posible guardar la configuracion de pantalla.",
        }
      );

      await cargarConfiguracion();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  async function guardarMangueras(posicion) {
    const payload =
      posicion.mangueras?.map((manguera) => {
        const draft = hoseDrafts[getHoseKey(manguera.idPosicionGrado)] || {};
        return {
          idPosicionGrado: manguera.idPosicionGrado,
          lado: (draft.lado || "").trim(),
          color: (draft.color || "").trim(),
        };
      }) ?? [];

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/GuardarManguera", payload);

          if (response.data?.success === false) {
            throw new Error(
              response.data?.message || "No fue posible guardar las mangueras."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando posiciones",
            message: `Estamos actualizando lados y colores de la posicion ${posicion.idPosicion}.`,
          },
          successMessage: `La posicion ${posicion.idPosicion} quedo actualizada.`,
          errorMessage: "No fue posible guardar la configuracion de mangueras.",
        }
      );

      await cargarConfiguracion();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  async function guardarMaximosPreset() {
    const payload = {
      productos:
        catalogos?.productos?.map((producto) => ({
          idProducto: producto.idProducto,
          maximoPreset: clampPreset(
            productDrafts[producto.idProducto] ?? producto.maximoPreset,
            producto.precio
          ),
        })) ?? [],
    };

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/GuardarMaximosPreset", payload);

          if (response.data?.success === false) {
            throw new Error(
              response.data?.message || "No fue posible guardar los maximos preset."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando productos",
            message: "Estamos actualizando los maximos preset del autoservicio.",
          },
          successMessage: "Los maximos preset quedaron actualizados.",
          errorMessage: "No fue posible guardar los maximos preset.",
        }
      );

      await cargarConfiguracion();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  async function guardarFormasPago() {
    const payload =
      catalogos?.formasPagoAuto?.map((formaPago) => {
        const draft = paymentDrafts[formaPago.idFormaPago] || {};
        const selectedSystem = catalogos?.formasPagoSistema?.find(
          (item) => item.idFormaPago === Number(draft.idFormaPago || 0)
        );

        return {
          idFormaPagoAuto: formaPago.idFormaPago,
          idFormaPago: Number(draft.idFormaPago || 0),
          descripcion: draft.descripcion || selectedSystem?.descripcion || formaPago.nombre || "",
          activo: Boolean(draft.activo ?? true),
        };
      }) ?? [];

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/ConfigurarFormaPago", payload);

          if (response.data?.success === false) {
            throw new Error(
              response.data?.message || "No fue posible guardar las formas de pago."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando formas de pago",
            message: "Estamos vinculando las formas de pago del sistema con autoservicio.",
          },
          successMessage: "Las formas de pago quedaron configuradas.",
          errorMessage: "No fue posible guardar las formas de pago.",
        }
      );

      await cargarConfiguracion();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  async function guardarFidelidad() {
    const payload = fidelidad.map((programa) => ({
      idFidelidad: programa.idFidelidad,
      nombre: programa.nombre,
      activo: Boolean(programa.activo),
    }));

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/GuardarFidelidad", payload);

          if (response.data?.success === false) {
            const errores = response.data?.errors;
            throw new Error(
              (Array.isArray(errores) && errores.filter(Boolean).join(" ")) ||
                response.data?.message ||
                "No fue posible guardar los programas de fidelidad."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando fidelidad",
            message: "Estamos actualizando los programas que se ofrecen en el autoservicio.",
          },
          successMessage: "Los programas de fidelidad quedaron actualizados.",
          errorMessage: "No fue posible guardar los programas de fidelidad.",
        }
      );

      await cargarConfiguracion();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  async function guardarFormasVendedor() {
    const payload = formasVendedor.map((forma) => ({
      idFormaPago: forma.idFormaPago,
      activo: Boolean(forma.activo),
    }));

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/ConfigurarFormasPagoVendedor", payload);

          if (response.data?.success === false) {
            throw new Error(
              response.data?.message || "No fue posible guardar las formas de pago del vendedor."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando formas de pago",
            message: "Estamos actualizando las formas de pago que ofrece el vendedor.",
          },
          successMessage: "Las formas de pago del vendedor quedaron actualizadas.",
          errorMessage: "No fue posible guardar las formas de pago del vendedor.",
        }
      );

      await cargarConfiguracion();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  async function guardarSistema() {
    const sistema = systemDraft?.sistema || "GNESYS";
    const maxVueltos = Number(systemDraft?.maxVueltos || 0);

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/GuardarConfiguracionEstacion", {
            sistema,
            maxVueltos: String(maxVueltos),
          });

          if (response.data?.success === false) {
            throw new Error(
              response.data?.message ||
                "No fue posible guardar la configuracion del sistema."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando sistema",
            message: "Estamos actualizando el tipo de sistema y el maximo de vueltos.",
          },
          successMessage: "La configuracion del sistema quedo actualizada.",
          errorMessage: "No fue posible guardar la configuracion del sistema.",
        }
      );

      await cargarConfiguracion();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  async function guardarMarcaciones() {
    const marcaciones = {
      dinero: padMarcaciones(marcacionesDraft?.dinero),
      volumen: padMarcaciones(marcacionesDraft?.volumen),
    };

    try {
      await portalFeedback.runWithFeedback(
        async () => {
          const response = await api.post("/Admin/GuardarMarcaciones", {
            marcaciones,
          });

          if (response.data?.success === false) {
            throw new Error(
              response.data?.message || "No fue posible guardar las marcaciones rapidas."
            );
          }
        },
        {
          minimumMs: 900,
          loading: {
            title: "Guardando marcaciones",
            message: "Estamos actualizando los valores rapidos de dinero y volumen.",
          },
          successMessage: "Las marcaciones rapidas quedaron actualizadas.",
          errorMessage: "No fue posible guardar las marcaciones rapidas.",
        }
      );

      await cargarConfiguracion();
    } catch {
      // El feedback global ya notifica el error.
    }
  }

  useEffect(() => {
    const timer = setTimeout(() => {
      cargarConfiguracion();
    }, 0);

    return () => clearTimeout(timer);
  }, [cargarConfiguracion]);

  if (loading) {
    return (
      <div style={styles.stateWrap}>
        <div style={styles.spinner} />
        <p style={styles.stateText}>Cargando configuracion inicial...</p>
      </div>
    );
  }

  if (error || !mapeo || !catalogos) {
    return (
      <div style={styles.stateWrap}>
        <p style={styles.errorText}>{error || "No hay informacion disponible."}</p>
        <button style={styles.retryBtn} onClick={cargarConfiguracion}>
          Reintentar
        </button>
      </div>
    );
  }

  const dispositivosPorDispensador = new Map(
    dispositivos.map((item) => [item.idDispensador, item])
  );

  const dispensadores = (mapeo.dispensadores ?? []).map((dispensador) => ({
    ...dispensador,
    dispositivo: dispositivosPorDispensador.get(dispensador.idDispensador) || null,
  }));
  const dispensadoresFiltrados =
    selectedDispensador === "all"
      ? dispensadores
      : dispensadores.filter(
          (dispensador) => String(dispensador.idDispensador) === selectedDispensador
        );

  const totalDispensadores = dispensadores.length;
  const totalAtados = dispensadores.filter((item) => item.dispositivo?.identificador).length;
  const totalPendientesEquipo = totalDispensadores - totalAtados;
  const pantallasPendientes = dispensadores.reduce(
    (acc, disp) =>
      acc +
      (disp.caras?.filter((cara) => {
        const firstPosition = cara.posiciones?.[0];
        return !cara.serialPantalla || !firstPosition?.codigoTankio;
      }).length ?? 0),
    0
  );
  const manguerasPendientes = dispensadores.reduce(
    (acc, disp) =>
      acc +
      (disp.caras?.reduce(
        (caraAcc, cara) =>
          caraAcc +
          (cara.posiciones?.reduce(
            (posAcc, posicion) =>
              posAcc +
              (posicion.mangueras?.filter(
                (manguera) => !manguera.lado || !manguera.color
              ).length ?? 0),
            0
          ) ?? 0),
        0
      ) ?? 0),
    0
  );
  const formasPagoAuto = catalogos.formasPagoAuto ?? [];
  const formasPagoSinConfigurar = formasPagoAuto.filter(
    (item) => !item.idFormaPagoSistema || item.idFormaPagoSistema === 0
  ).length;

  return (
    <div style={styles.wrap}>
      <section style={styles.header}>
        <div>
          <div style={styles.headerTop}>
            <Pill tone="blue">Configuracion</Pill>
            <span style={styles.headerCaption}>Autoservicio y parametros base</span>
          </div>
          <h3 style={styles.title}>Configuracion inicial y ajustes posteriores</h3>
          <p style={styles.subtitle}>
            {mapeo.estacion?.nombreEDS || "EDS"} · Controla equipos atados,
            pantallas, codigos Tankio y lados o colores por posicion grado.
          </p>
        </div>

        <button style={styles.refreshBtn} onClick={cargarConfiguracion}>
          <RefreshIcon />
          <span>Actualizar</span>
        </button>
      </section>

      <section className="cfg-stats-grid">
        <StatCard label="Dispensadores" value={totalDispensadores} nota="en la estacion" tone="blue" />
        <StatCard label="Equipos atados" value={totalAtados} nota="con dispositivo" tone="green" />
        <StatCard label="Dispensadores sin equipo" value={totalPendientesEquipo} pendiente />
        <StatCard label="Pantallas pendientes" value={pantallasPendientes} pendiente />
        <StatCard label="Mangueras pendientes" value={manguerasPendientes} pendiente />
        <StatCard label="Pagos pendientes" value={formasPagoSinConfigurar} pendiente />
      </section>

      <section className="cfg-section-nav" role="tablist" aria-label="Secciones de configuracion">
        {[
          { id: "sistema", label: "Sistema", description: "NSX o GNESYS y vueltos", icon: "sistema" },
          { id: "marcaciones", label: "Marcaciones", description: "Dinero y volumen rapido", icon: "marcaciones" },
          { id: "equipos", label: "Equipos", description: "Dispositivos atados", icon: "equipos", pendientes: totalPendientesEquipo },
          { id: "posiciones", label: "Posiciones", description: "Pantallas y Tankio", icon: "posiciones", pendientes: pantallasPendientes },
          { id: "mangueras", label: "Mangueras", description: "Lados y colores", icon: "mangueras", pendientes: manguerasPendientes },
          { id: "productos", label: "Productos", description: "Maximos preset", icon: "productos" },
          { id: "pagos", label: "Pagos", description: "Anclajes del sistema", icon: "pagos", pendientes: formasPagoSinConfigurar },
          {
            id: "fidelidad",
            label: "Fidelidad",
            description: "Programas que se ofrecen",
            icon: "fidelidad",
            activos: fidelidad.filter((programa) => programa.activo).length,
          },
        ].map((seccion) => (
          <SectionToggle
            key={seccion.id}
            label={seccion.label}
            description={seccion.description}
            icon={seccion.icon}
            badge={
              seccion.pendientes === undefined
                ? seccion.activos === undefined
                  ? null
                  : { texto: `${seccion.activos} ${seccion.activos === 1 ? "activo" : "activos"}`, tono: "blue" }
                : seccion.pendientes === 0
                  ? { texto: "✓", tono: "green" }
                  : { texto: String(seccion.pendientes), tono: "amber" }
            }
            active={activeSection === seccion.id}
            onClick={() => setActiveSection(seccion.id)}
          />
        ))}
      </section>

      {activeSection === "sistema" && (
        <>
          <SectionHeader
            title="Sistema y vueltos"
            subtitle="Define si la estacion opera con NSX o GNESYS, y el maximo de vueltos permitido en efectivo."
          />
          <section style={styles.productsLayout}>
            <article style={styles.card}>
              <div style={styles.cardTop}>
                <div>
                  <div style={styles.cardTitleWrap}>
                    <h4 style={styles.cardTitle}>Configuracion general</h4>
                    <Pill tone="blue">{systemDraft?.sistema || "Sin definir"}</Pill>
                  </div>
                  <p style={styles.cardMeta}>
                    Estos valores aplican a toda la estacion{" "}
                    {mapeo.estacion?.nombreEDS || "EDS"}.
                  </p>
                </div>
              </div>

              <div className="cfg-form-grid" style={styles.formGrid}>
                <label style={styles.field}>
                  <span style={styles.fieldLabel}>Sistema</span>
                  <select
                    style={styles.select}
                    value={systemDraft?.sistema || "GNESYS"}
                    onChange={(event) =>
                      setSystemDraft((current) => ({
                        ...current,
                        sistema: event.target.value,
                      }))
                    }
                  >
                    <option value="NSX">NSX</option>
                    <option value="GNESYS">GNESYS</option>
                  </select>
                </label>

                <label style={styles.field}>
                  <span style={styles.fieldLabel}>Maximo vueltos</span>
                  <input
                    style={styles.input}
                    type="number"
                    min={0}
                    max={999999}
                    value={systemDraft?.maxVueltos ?? 0}
                    onChange={(event) =>
                      setSystemDraft((current) => ({
                        ...current,
                        maxVueltos: event.target.value,
                      }))
                    }
                    onBlur={(event) =>
                      setSystemDraft((current) => ({
                        ...current,
                        maxVueltos: clampNumberInRange(event.target.value, 0, 999999),
                      }))
                    }
                  />
                </label>
              </div>

              <div style={styles.inlineActions}>
                <button type="button" style={styles.primaryBtn} onClick={guardarSistema}>
                  Guardar sistema
                </button>
              </div>
            </article>
          </section>
        </>
      )}

      {activeSection === "marcaciones" && (
        <>
          <SectionHeader
            title="Marcaciones rapidas"
            subtitle="Define los 3 valores rapidos de dinero y los 3 de volumen que vera el cliente en autoservicio."
          />
          <section style={styles.productsLayout}>
            <article style={styles.card}>
              <div style={styles.cardTop}>
                <div>
                  <div style={styles.cardTitleWrap}>
                    <h4 style={styles.cardTitle}>Marcaciones de dinero</h4>
                    <Pill tone="blue">3 valores</Pill>
                  </div>
                  <p style={styles.cardMeta}>
                    Montos rapidos en pesos que el cliente puede escoger de una vez.
                  </p>
                </div>
              </div>

              <div className="cfg-marcaciones-grid" style={styles.marcacionesGrid}>
                {[0, 1, 2].map((index) => (
                  <label key={`dinero-${index}`} style={styles.field}>
                    <span style={styles.fieldLabel}>Marcacion {index + 1}</span>
                    <input
                      style={styles.input}
                      type="number"
                      min={0}
                      max={999999}
                      value={marcacionesDraft?.dinero?.[index] ?? 0}
                      onChange={(event) =>
                        setMarcacionesDraft((current) => {
                          const dinero = [...(current?.dinero ?? padMarcaciones())];
                          dinero[index] = event.target.value;
                          return { ...current, dinero };
                        })
                      }
                      onBlur={(event) =>
                        setMarcacionesDraft((current) => {
                          const dinero = [...(current?.dinero ?? padMarcaciones())];
                          dinero[index] = clampNumberInRange(event.target.value, 0, 999999);
                          return { ...current, dinero };
                        })
                      }
                    />
                  </label>
                ))}
              </div>
            </article>

            <article style={styles.card}>
              <div style={styles.cardTop}>
                <div>
                  <div style={styles.cardTitleWrap}>
                    <h4 style={styles.cardTitle}>Marcaciones de volumen</h4>
                    <Pill tone="green">3 valores</Pill>
                  </div>
                  <p style={styles.cardMeta}>
                    Galones rapidos que el cliente puede escoger de una vez.
                  </p>
                </div>
              </div>

              <div className="cfg-marcaciones-grid" style={styles.marcacionesGrid}>
                {[0, 1, 2].map((index) => (
                  <label key={`volumen-${index}`} style={styles.field}>
                    <span style={styles.fieldLabel}>Marcacion {index + 1}</span>
                    <input
                      style={styles.input}
                      type="number"
                      min={0}
                      max={9999}
                      value={marcacionesDraft?.volumen?.[index] ?? 0}
                      onChange={(event) =>
                        setMarcacionesDraft((current) => {
                          const volumen = [...(current?.volumen ?? padMarcaciones())];
                          volumen[index] = event.target.value;
                          return { ...current, volumen };
                        })
                      }
                      onBlur={(event) =>
                        setMarcacionesDraft((current) => {
                          const volumen = [...(current?.volumen ?? padMarcaciones())];
                          volumen[index] = clampNumberInRange(event.target.value, 0, 9999);
                          return { ...current, volumen };
                        })
                      }
                    />
                  </label>
                ))}
              </div>

              <div style={styles.inlineActions}>
                <button type="button" style={styles.primaryBtn} onClick={guardarMarcaciones}>
                  Guardar marcaciones
                </button>
              </div>
            </article>
          </section>
        </>
      )}

      {activeSection === "equipos" && (
        <>
          <SectionHeader
            title="Equipos atados a autoservicio"
            subtitle="Aqui se ve rapido que dispensadores ya tienen identificador y cuales requieren atarlo."
          />
      <section style={styles.cardList}>
        {dispensadores.map((dispensador) => {
          const draft =
            deviceDrafts[dispensador.idDispensador] ?? {
              idDispositivo: dispensador.dispositivo?.idDispositivo || 0,
              idDispensador: dispensador.idDispensador,
              identificador: dispensador.dispositivo?.identificador || "",
              ip: dispensador.dispositivo?.ip || "",
              activo: dispensador.dispositivo?.activo ?? true,
              modoHibrido: dispensador.dispositivo?.modoHibrido ?? false,
              tiempoReal: dispensador.dispositivo?.tiempoReal ?? false,
              intervaloTiempoReal: dispensador.dispositivo?.intervaloTiempoReal ?? 500,
              identificadoresCliente:
                dispensador.dispositivo?.identificadoresCliente || "1|1|1",
            };
          const hasDevice = Boolean(dispensador.dispositivo);
          const identificadoresActivos = parseIdentificadores(draft.identificadoresCliente);

          return (
            <article key={dispensador.idDispensador} style={styles.card}>
              <div style={styles.cardTop}>
                <div style={styles.cardLead}>
                  <div style={styles.cardIndex}>{dispensador.idDispensador}</div>
                  <div>
                    <div style={styles.cardTitleWrap}>
                      <h4 style={styles.cardTitle}>
                        Dispensador {dispensador.idDispensador}
                      </h4>
                      <Pill tone={hasDevice ? "green" : "amber"}>
                        {hasDevice ? "Atado" : "Pendiente"}
                      </Pill>
                    </div>
                    <p style={styles.cardMeta}>
                      Tipo {dispensador.tipoDispensador ?? "N/D"}
                    </p>
                  </div>
                </div>
              </div>

              {hasDevice ? (
                <div style={styles.infoBox}>
                  <div className="cfg-device-info-grid" style={styles.deviceInfoGrid}>
                    <div>
                      <p style={styles.infoLabel}>Identificador actual</p>
                      <p style={styles.infoValue}>{dispensador.dispositivo.identificador}</p>
                    </div>
                    <div>
                      <p style={styles.infoLabel}>IP actual</p>
                      <p style={styles.infoValue}>{dispensador.dispositivo.ip || "Sin IP"}</p>
                    </div>
                    <div>
                      <p style={styles.infoLabel}>Estado</p>
                      <p style={styles.infoValue}>
                        {dispensador.dispositivo.activo ? "Activo" : "Inactivo"}
                      </p>
                    </div>
                  </div>
                  <Pill tone={dispensador.dispositivo.activo ? "green" : "amber"}>
                    {dispensador.dispositivo.activo ? "Habilitado" : "Deshabilitado"}
                  </Pill>
                </div>
              ) : (
                <div style={styles.infoBox}>
                  <div>
                    <p style={styles.infoLabel}>Estado</p>
                    <p style={styles.infoValue}>Sin dispositivo configurado</p>
                  </div>
                  <Pill tone="amber">Pendiente</Pill>
                </div>
              )}

              <div style={styles.editorBox}>
                <div style={styles.editorHeader}>
                  <p style={styles.editorTitle}>
                    {hasDevice ? "Editar dispositivo" : "Configurar dispositivo"}
                  </p>
                  {hasDevice && !deviceEditing[dispensador.idDispensador] ? (
                    <button
                      type="button"
                      style={styles.secondaryBtn}
                      onClick={() => {
                        setDeviceDrafts((current) => ({
                          ...current,
                          [dispensador.idDispensador]: {
                            idDispositivo: dispensador.dispositivo.idDispositivo || 0,
                            idDispensador: dispensador.idDispensador,
                            identificador: dispensador.dispositivo.identificador || "",
                            ip: dispensador.dispositivo.ip || "",
                            activo: dispensador.dispositivo.activo ?? true,
                            modoHibrido: dispensador.dispositivo.modoHibrido ?? false,
                            tiempoReal: dispensador.dispositivo.tiempoReal ?? false,
                            intervaloTiempoReal: dispensador.dispositivo.intervaloTiempoReal ?? 500,
                            identificadoresCliente:
                              dispensador.dispositivo.identificadoresCliente || "1|1|1",
                          },
                        }));
                        setDeviceEditing((current) => ({
                          ...current,
                          [dispensador.idDispensador]: true,
                        }));
                      }}
                    >
                      Editar
                    </button>
                  ) : null}
                </div>

                {hasDevice && !deviceEditing[dispensador.idDispensador] ? (
                  <div style={styles.editorPreview}>
                    <div>
                      <p style={styles.infoLabel}>Identificador</p>
                      <p style={styles.infoValue}>{draft.identificador || "Sin dato"}</p>
                    </div>
                    <div>
                      <p style={styles.infoLabel}>IP</p>
                      <p style={styles.infoValue}>{draft.ip || "Sin dato"}</p>
                    </div>
                    <div>
                      <p style={styles.infoLabel}>Activo</p>
                      <p style={styles.infoValue}>{draft.activo ? "Si" : "No"}</p>
                    </div>
                    <div>
                      <p style={styles.infoLabel}>Acceso de vendedor</p>
                      <div style={styles.pillRow}>
                        <Pill tone={draft.modoHibrido ? "green" : "neutral"}>
                          {draft.modoHibrido ? "Habilitado" : "No habilitado"}
                        </Pill>
                      </div>
                    </div>
                    <div>
                      <p style={styles.infoLabel}>Tiempo real</p>
                      <div style={styles.pillRow}>
                        <Pill tone={draft.tiempoReal ? "green" : "neutral"}>
                          {draft.tiempoReal ? `Cada ${draft.intervaloTiempoReal ?? 500} ms` : "Apagado"}
                        </Pill>
                      </div>
                    </div>
                    <div>
                      <p style={styles.infoLabel}>Identificadores</p>
                      <div style={styles.pillRow}>
                        {IDENTIFICADORES.filter((_, index) => identificadoresActivos[index]).map(
                          (item) => (
                            <Pill key={item.label} tone="blue">
                              {item.label}
                            </Pill>
                          )
                        )}
                        {!identificadoresActivos.some(Boolean) && <Pill tone="amber">Ninguno</Pill>}
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="cfg-device-editor">
                    <div className="cfg-editor-grid">
                      <label style={styles.field}>
                        <span style={styles.fieldLabel}>Identificador del equipo</span>
                        <input
                          style={styles.input}
                          placeholder="Ej. 147D62C3B444"
                          maxLength={60}
                          value={draft.identificador}
                          onChange={(event) =>
                            setDeviceDrafts((current) => ({
                              ...current,
                              [dispensador.idDispensador]: {
                                ...draft,
                                identificador: sanitizeText(event.target.value),
                              },
                            }))
                          }
                        />
                        <span style={styles.fieldHint}>
                          MAC de 12 caracteres, sin separadores.
                        </span>
                      </label>
                      <label style={styles.field}>
                        <span style={styles.fieldLabel}>Direccion IP</span>
                        <input
                          style={styles.input}
                          placeholder="Ej. 200.118.226.75:5007"
                          maxLength={60}
                          value={draft.ip}
                          onChange={(event) =>
                            setDeviceDrafts((current) => ({
                              ...current,
                              [dispensador.idDispensador]: {
                                ...draft,
                                ip: sanitizeText(event.target.value),
                              },
                            }))
                          }
                        />
                        <span style={styles.fieldHint}>Con el puerto, si lo usa.</span>
                      </label>
                    </div>

                    <div>
                      <p style={styles.groupLabel}>Opciones del equipo</p>
                      <div className="cfg-editor-grid">
                        <SwitchCard
                          checked={Boolean(draft.activo)}
                          title="Equipo activo"
                          description="Aparece en el mapeo y responde a la app."
                          onChange={(checked) =>
                            setDeviceDrafts((current) => ({
                              ...current,
                              [dispensador.idDispensador]: { ...draft, activo: checked },
                            }))
                          }
                        />
                        <SwitchCard
                          checked={Boolean(draft.modoHibrido)}
                          title="Acceso de vendedor"
                          description="Un vendedor puede vender desde esta pantalla."
                          onChange={(checked) =>
                            setDeviceDrafts((current) => ({
                              ...current,
                              [dispensador.idDispensador]: { ...draft, modoHibrido: checked },
                            }))
                          }
                        />
                        <SwitchCard
                          checked={Boolean(draft.tiempoReal)}
                          title="Tiempo real"
                          description="La pantalla muestra valor y avance mientras surte."
                          onChange={(checked) =>
                            setDeviceDrafts((current) => ({
                              ...current,
                              [dispensador.idDispensador]: { ...draft, tiempoReal: checked },
                            }))
                          }
                        />
                        {draft.tiempoReal ? (
                          <label style={styles.field}>
                            <span style={styles.fieldLabel}>Actualizar cada (ms)</span>
                            <input
                              style={styles.input}
                              type="number"
                              min={200}
                              max={5000}
                              step={100}
                              value={draft.intervaloTiempoReal ?? 500}
                              onChange={(event) =>
                                setDeviceDrafts((current) => ({
                                  ...current,
                                  [dispensador.idDispensador]: {
                                    ...draft,
                                    intervaloTiempoReal: event.target.value,
                                  },
                                }))
                              }
                            />
                            <span style={styles.fieldHint}>Entre 200 y 5000. Recomendado 500.</span>
                          </label>
                        ) : null}
                      </div>
                    </div>

                    <div>
                      <p style={styles.groupLabel}>Como se identifica el cliente</p>
                      <div className="cfg-choice-grid">
                        {IDENTIFICADORES.map((tipo, index) => (
                          <ChoiceCard
                            key={tipo.label}
                            checked={identificadoresActivos[index]}
                            title={tipo.label}
                            description={tipo.description}
                            icon={tipo.icon}
                            onChange={(checked) =>
                              setDeviceDrafts((current) => {
                                const flags = parseIdentificadores(draft.identificadoresCliente);
                                flags[index] = checked;
                                return {
                                  ...current,
                                  [dispensador.idDispensador]: {
                                    ...draft,
                                    identificadoresCliente: buildIdentificadores(flags),
                                  },
                                };
                              })
                            }
                          />
                        ))}
                      </div>
                      <p style={styles.fieldHint}>
                        {identificadoresActivos.some(Boolean)
                          ? "La app solo ofrece al cliente los que esten marcados."
                          : "Sin ningun identificador el cliente no podra pagar a cuenta."}
                      </p>
                    </div>

                    <div style={styles.inlineActions}>
                      <button
                        type="button"
                        style={{ ...styles.primaryBtn, minHeight: 46, padding: "0 28px", fontSize: 14 }}
                        onClick={() => guardarDispositivo(dispensador.idDispensador)}
                      >
                        {hasDevice ? "Guardar cambios" : "Atar equipo"}
                      </button>
                      {hasDevice ? (
                        <button
                          type="button"
                          style={styles.cancelBtn}
                          onClick={() => {
                            setDeviceDrafts((current) => ({
                              ...current,
                              [dispensador.idDispensador]: {
                                idDispositivo: dispensador.dispositivo.idDispositivo || 0,
                                idDispensador: dispensador.idDispensador,
                                identificador: dispensador.dispositivo.identificador || "",
                                ip: dispensador.dispositivo.ip || "",
                                activo: dispensador.dispositivo.activo ?? true,
                                modoHibrido: dispensador.dispositivo.modoHibrido ?? false,
                                tiempoReal: dispensador.dispositivo.tiempoReal ?? false,
                                intervaloTiempoReal: dispensador.dispositivo.intervaloTiempoReal ?? 500,
                                identificadoresCliente:
                                  dispensador.dispositivo.identificadoresCliente || "1|1|1",
                              },
                            }));
                            setDeviceEditing((current) => ({
                              ...current,
                              [dispensador.idDispensador]: false,
                            }));
                          }}
                        >
                          Cancelar
                        </button>
                      ) : null}
                    </div>
                  </div>
                )}
              </div>
            </article>
          );
        })}
          </section>
        </>
      )}

      {activeSection === "posiciones" && (
        <>
          <SectionHeader
            title="Configurar posiciones y pantallas"
            subtitle="Aqui se define serial de pantalla y codigo Tankio. Solo usa la primera posicion de cada cara para guardar."
          />
          <DispensadorFilter
            value={selectedDispensador}
            onChange={setSelectedDispensador}
            dispensadores={dispensadores}
            helper="Escoge el dispensador que quieres configurar para no cargar toda la estacion al mismo tiempo."
          />
          <section style={styles.cardList}>
        {dispensadoresFiltrados.map((dispensador) => (
          <article key={`positions-${dispensador.idDispensador}`} style={styles.groupCard}>
            <div style={styles.groupHeader}>
              <div style={styles.groupHeaderLead}>
                <div style={styles.cardIndex}>{dispensador.idDispensador}</div>
                <div>
                  <h4 style={styles.cardTitle}>Dispensador {dispensador.idDispensador}</h4>
                  <p style={styles.cardMeta}>
                    {plural((dispensador.caras ?? []).length, "cara", "caras")} para configurar
                  </p>
                </div>
              </div>
            </div>

            <div style={styles.groupBody}>
              {(dispensador.caras ?? []).map((cara) => {
                const firstPosition = cara.posiciones?.[0];
                if (!firstPosition) return null;

                const draft =
                  screenDrafts[getScreenKey(firstPosition.idPosicion)] || {
                    idPosicion: firstPosition.idPosicion,
                    serialPantalla: cara.serialPantalla || "",
                    codigoTankio: firstPosition.codigoTankio || "",
                  };

                const hasPending = !cara.serialPantalla || !firstPosition.codigoTankio;

                return (
                  <article
                    key={`screen-${dispensador.idDispensador}-${cara.numeroCara}`}
                    style={styles.card}
                  >
                    <div style={styles.cardTop}>
                      <div>
                        <div style={styles.cardTitleWrap}>
                          <h4 style={styles.cardTitle}>Cara {cara.numeroCara}</h4>
                          <Pill tone={hasPending ? "amber" : "green"}>
                            {hasPending ? "Pendiente" : "Configurada"}
                          </Pill>
                        </div>
                        <p style={styles.cardMeta}>
                          Guarda con la posicion {firstPosition.idPosicion} como base de la cara
                        </p>
                      </div>
                    </div>

                    <div className="cfg-form-grid" style={styles.formGrid}>
                      <label style={styles.field}>
                        <span style={styles.fieldLabel}>Serial pantalla</span>
                        <input
                          style={styles.input}
                          maxLength={60}
                          value={draft.serialPantalla}
                          onChange={(event) =>
                            setScreenDrafts((current) => ({
                              ...current,
                              [getScreenKey(firstPosition.idPosicion)]: {
                                ...draft,
                                serialPantalla: sanitizeText(event.target.value),
                              },
                            }))
                          }
                        />
                      </label>

                      <label style={styles.field}>
                        <span style={styles.fieldLabel}>Codigo Tankio</span>
                        <input
                          style={styles.input}
                          maxLength={60}
                          value={draft.codigoTankio}
                          onChange={(event) =>
                            setScreenDrafts((current) => ({
                              ...current,
                              [getScreenKey(firstPosition.idPosicion)]: {
                                ...draft,
                                codigoTankio: sanitizeText(event.target.value),
                              },
                            }))
                          }
                        />
                      </label>
                    </div>

                    <div style={styles.inlineActions}>
                      <button
                        type="button"
                        style={styles.primaryBtn}
                        onClick={() => guardarPantalla(draft)}
                      >
                        Guardar pantalla
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>
          </article>
        ))}
          </section>
        </>
      )}

      {activeSection === "mangueras" && (
        <>
          <SectionHeader
            title="Configurar lados y colores"
            subtitle="Cada tarjeta guarda las mangueras de una posicion usando idPosicionGrado para lado y color."
          />
          <DispensadorFilter
            value={selectedDispensador}
            onChange={setSelectedDispensador}
            dispensadores={dispensadores}
            helper="Filtra por dispensador para trabajar las mangueras de una isla puntual sin recorrer toda la estacion."
          />
          <section style={styles.cardList}>
        {dispensadoresFiltrados.map((dispensador) => (
          <article key={`hoses-${dispensador.idDispensador}`} style={styles.groupCard}>
            <div style={styles.groupHeader}>
              <div style={styles.groupHeaderLead}>
                <div style={styles.cardIndex}>{dispensador.idDispensador}</div>
                <div>
                  <h4 style={styles.cardTitle}>Dispensador {dispensador.idDispensador}</h4>
                  <p style={styles.cardMeta}>
                    {plural(
                      (dispensador.caras ?? []).reduce(
                        (acc, cara) => acc + (cara.posiciones?.length ?? 0),
                        0
                      ),
                      "posicion",
                      "posiciones"
                    )}{" "}
                    para revisar
                  </p>
                </div>
              </div>
            </div>

            <div style={styles.groupBody}>
              {(dispensador.caras ?? []).flatMap((cara) =>
                (cara.posiciones ?? []).map((posicion) => {
                  const hasPending = posicion.mangueras?.some(
                    (manguera) => !manguera.lado || !manguera.color
                  );

                  return (
                    <article
                      key={`hose-${posicion.idPosicion}`}
                      style={styles.card}
                    >
                      <div style={styles.cardTop}>
                        <div>
                          <div style={styles.cardTitleWrap}>
                            <h4 style={styles.cardTitle}>
                              Cara {cara.numeroCara} · Posicion {posicion.idPosicion}
                            </h4>
                            <Pill tone={hasPending ? "amber" : "green"}>
                              {hasPending ? "Incompleta" : "Lista"}
                            </Pill>
                          </div>
                          <p style={styles.cardMeta}>
                            Configura lado y color para cada posicion grado
                          </p>
                        </div>
                      </div>

                      <div style={styles.hoseGrid}>
                        {(posicion.mangueras ?? []).map((manguera) => {
                          const draft =
                            hoseDrafts[getHoseKey(manguera.idPosicionGrado)] || {
                              idPosicionGrado: manguera.idPosicionGrado,
                              lado: manguera.lado || "",
                              color: manguera.color || "",
                            };
                          const colorPreview = getColorPreview(draft.color);

                          return (
                            <div
                              key={manguera.idPosicionGrado}
                              style={styles.hoseItem}
                            >
                              <div style={styles.hoseHeader}>
                                <div>
                                  <p style={styles.hoseTitle}>
                                    {manguera.producto?.nombreProducto || "Producto"}
                                  </p>
                                  <p style={styles.hoseMeta}>
                                    Grado {manguera.idPosicionGrado} · Manguera {manguera.numero}
                                  </p>
                                </div>
                                <div
                                  style={{
                                    ...styles.colorSwatch,
                                    background: colorPreview || "#e8edf4",
                                  }}
                                />
                              </div>

                              <div style={styles.hoseFields}>
                                <label style={styles.field}>
                                  <span style={styles.fieldLabel}>Lado</span>
                                  <select
                                    style={styles.select}
                                    value={draft.lado}
                                    onChange={(event) =>
                                      setHoseDrafts((current) => ({
                                        ...current,
                                        [getHoseKey(manguera.idPosicionGrado)]: {
                                          ...draft,
                                          lado: event.target.value,
                                        },
                                      }))
                                    }
                                  >
                                    <option value="">Selecciona</option>
                                    <option value="I">I</option>
                                    <option value="M">M</option>
                                    <option value="D">D</option>
                                  </select>
                                </label>

                                <label style={styles.field}>
                                  <span style={styles.fieldLabel}>Color</span>
                                  <div style={styles.colorField}>
                                    <input
                                      type="color"
                                      style={styles.colorInput}
                                      value={normalizeHexForPicker(draft.color)}
                                      onChange={(event) =>
                                        setHoseDrafts((current) => ({
                                          ...current,
                                          [getHoseKey(manguera.idPosicionGrado)]: {
                                            ...draft,
                                            color: pickerToStoredHex(event.target.value, draft.color),
                                          },
                                        }))
                                      }
                                    />
                                    <input
                                      style={styles.input}
                                      value={draft.color}
                                      placeholder="#FFFF0000"
                                      maxLength={9}
                                      onChange={(event) =>
                                        setHoseDrafts((current) => ({
                                          ...current,
                                          [getHoseKey(manguera.idPosicionGrado)]: {
                                            ...draft,
                                            color: sanitizeHexColor(event.target.value),
                                          },
                                        }))
                                      }
                                    />
                                  </div>
                                </label>
                              </div>
                            </div>
                          );
                        })}
                      </div>

                      <div style={styles.inlineActions}>
                        <button
                          type="button"
                          style={styles.primaryBtn}
                          onClick={() => guardarMangueras(posicion)}
                        >
                          Guardar posicion
                        </button>
                      </div>
                    </article>
                  );
                })
              )}
            </div>
          </article>
        ))}
          </section>
        </>
      )}

      {activeSection === "productos" && (
        <>
          <SectionHeader
            title="Configurar productos"
            subtitle="Ajusta los maximos preset de cada producto del autoservicio."
          />
          <section style={styles.productsLayout}>
            <article style={styles.card}>
              <div style={styles.cardTop}>
                <div>
                  <div style={styles.cardTitleWrap}>
                    <h4 style={styles.cardTitle}>Productos</h4>
                    <Pill tone="blue">{plural(catalogos.productos?.length ?? 0, "item", "items")}</Pill>
                  </div>
                  <p style={styles.cardMeta}>
                    Edita el maximo preset que podra usar cada producto en autoservicio.
                  </p>
                </div>
              </div>

              <div style={styles.productGrid}>
                {(catalogos.productos ?? []).map((producto) => (
                  <div key={producto.idProducto} className="cfg-product-item" style={styles.productItem}>
                    <div>
                      <p style={styles.productTitle}>{producto.nombreProducto}</p>
                      <p style={styles.productMeta}>
                        ${formatNumber(producto.precio)} · {producto.unidadMedida}
                      </p>
                    </div>
                    <label style={styles.field}>
                      <span style={styles.fieldLabel}>Maximo preset</span>
                      <input
                        style={styles.input}
                        type="number"
                        min={getPresetBounds(producto.precio).min}
                        max={getPresetBounds(producto.precio).max}
                        value={productDrafts[producto.idProducto] ?? producto.maximoPreset ?? 0}
                        onChange={(event) =>
                          setProductDrafts((current) => ({
                            ...current,
                            [producto.idProducto]: event.target.value,
                          }))
                        }
                        onBlur={(event) =>
                          setProductDrafts((current) => ({
                            ...current,
                            [producto.idProducto]: clampPreset(
                              event.target.value,
                              producto.precio
                            ),
                          }))
                        }
                      />
                      <span style={styles.fieldHint}>
                        Entre ${formatNumber(getPresetBounds(producto.precio).min)} y $
                        {formatNumber(getPresetBounds(producto.precio).max)}
                      </span>
                    </label>
                  </div>
                ))}
              </div>

              <div style={styles.inlineActions}>
                <button type="button" style={styles.primaryBtn} onClick={guardarMaximosPreset}>
                  Guardar productos
                </button>
              </div>
            </article>
          </section>
        </>
      )}

      {activeSection === "pagos" && (
        <>
          <SectionHeader
            title="Configurar formas de pago"
            subtitle="Aqui aparecen las formas de pago del autoservicio. Si estan en 0, aun no tienen forma de pago del sistema anclada."
          />
          <section style={styles.productsLayout}>
            <article style={styles.card}>
              <div style={styles.cardTop}>
                <div>
                  <div style={styles.cardTitleWrap}>
                    <h4 style={styles.cardTitle}>Formas de pago del autoservicio</h4>
                    <Pill tone="blue">{plural(formasPagoAuto.length, "item", "items")}</Pill>
                    <Pill tone={formasPagoSinConfigurar > 0 ? "amber" : "green"}>
                      {formasPagoSinConfigurar > 0
                        ? `${formasPagoSinConfigurar} sin configurar`
                        : "Todo configurado"}
                    </Pill>
                  </div>
                  <p style={styles.cardMeta}>
                    Selecciona de la lista la forma de pago del sistema a la que se va a anclar cada item del autoservicio.
                  </p>
                </div>
              </div>

              <div style={styles.productGrid}>
                {formasPagoAuto.length === 0 && (
                  <div style={styles.emptyInlineState}>
                    <p style={styles.emptyInlineTitle}>No hay formas de pago disponibles</p>
                    <p style={styles.emptyInlineText}>
                      Cuando el servicio entregue formas de pago del autoservicio, se podran anclar aqui.
                    </p>
                  </div>
                )}

                {formasPagoAuto.map((formaPago) => {
                  const draft = paymentDrafts[formaPago.idFormaPago] || {
                    idFormaPagoAuto: formaPago.idFormaPago,
                    idFormaPago: formaPago.idFormaPagoSistema ?? 0,
                    descripcion: formaPago.nombre || "",
                    activo: formaPago.activo ?? true,
                  };
                  const isPending = !draft.idFormaPago || draft.idFormaPago === 0;
                  const isActive = Boolean(draft.activo ?? true);

                  return (
                    <div
                      key={formaPago.idFormaPago}
                      className="cfg-product-item"
                      style={styles.productItem}
                    >
                      <div>
                        <div style={styles.cardTitleWrap}>
                          <p style={styles.productTitle}>{formaPago.nombre}</p>
                          <Pill tone={isPending ? "amber" : "green"}>
                            {isPending ? "Sin configurar" : "Anclada"}
                          </Pill>
                          <Pill tone={isActive ? "green" : "amber"}>
                            {isActive ? "Habilitada" : "Inhabilitada"}
                          </Pill>
                        </div>
                        <p style={styles.productMeta}>
                          Forma auto #{formaPago.idFormaPago} · Id sistema actual{" "}
                          {formaPago.idFormaPagoSistema ?? 0}
                        </p>
                      </div>

                      <div className="cfg-payment-fields" style={styles.paymentFields}>
                        <SwitchCard
                          checked={isActive}
                          title={isActive ? "Habilitada" : "Inhabilitada"}
                          description="Disponible en el autoservicio."
                          onChange={(checked) =>
                            setPaymentDrafts((current) => ({
                              ...current,
                              [formaPago.idFormaPago]: { ...draft, activo: checked },
                            }))
                          }
                        />

                        <label style={styles.field}>
                          <span style={styles.fieldLabel}>Forma del sistema</span>
                          <select
                            style={styles.select}
                            value={draft.idFormaPago}
                            onChange={(event) => {
                              const selectedId = Number(event.target.value);
                              const selected = catalogos.formasPagoSistema?.find(
                                (item) => item.idFormaPago === selectedId
                              );

                              setPaymentDrafts((current) => ({
                                ...current,
                                [formaPago.idFormaPago]: {
                                  ...draft,
                                  idFormaPago: selectedId,
                                  descripcion: selected?.descripcion || draft.descripcion,
                                },
                              }));
                            }}
                          >
                            <option value={0}>Selecciona</option>
                            {(catalogos.formasPagoSistema ?? []).map((item) => (
                              <option key={item.idFormaPago} value={item.idFormaPago}>
                                {item.descripcion}
                              </option>
                            ))}
                          </select>
                        </label>

                        <label style={styles.field}>
                          <span style={styles.fieldLabel}>Descripcion</span>
                          <input
                            style={styles.input}
                            maxLength={60}
                            value={draft.descripcion}
                            onChange={(event) =>
                              setPaymentDrafts((current) => ({
                                ...current,
                                [formaPago.idFormaPago]: {
                                  ...draft,
                                  descripcion: sanitizeText(event.target.value),
                                },
                              }))
                            }
                          />
                        </label>
                      </div>
                    </div>
                  );
                })}
              </div>

              <div style={styles.inlineActions}>
                <button type="button" style={styles.primaryBtn} onClick={guardarFormasPago}>
                  Guardar formas de pago
                </button>
              </div>
            </article>
          </section>

          <section style={styles.productsLayout}>
            <article style={styles.card}>
              <div style={styles.cardTop}>
                <div>
                  <div style={styles.cardTitleWrap}>
                    <h4 style={styles.cardTitle}>Formas de pago del vendedor</h4>
                    <Pill tone="blue">{plural(formasVendedor.length, "item", "items")}</Pill>
                    <Pill tone={formasVendedor.some((item) => item.activo) ? "green" : "amber"}>
                      {plural(formasVendedor.filter((item) => item.activo).length, "habilitada", "habilitadas")}
                    </Pill>
                  </div>
                  <p style={styles.cardMeta}>
                    Son las formas de pago que el vendedor puede anclar a su venta. Lo que no se ancla queda en efectivo. Es independiente de las del autoservicio.
                  </p>
                </div>
              </div>

              <div style={styles.productGrid}>
                {formasVendedor.length === 0 && (
                  <div style={styles.emptyInlineState}>
                    <p style={styles.emptyInlineTitle}>No hay formas de pago disponibles</p>
                    <p style={styles.emptyInlineText}>
                      El servicio no entrego la lista de formas de pago del vendedor.
                    </p>
                  </div>
                )}

                {formasVendedor.map((forma) => (
                  <div
                    key={forma.idFormaPago}
                    className="cfg-product-item"
                    style={styles.productItem}
                  >
                    <div>
                      <div style={styles.cardTitleWrap}>
                        <p style={styles.productTitle}>{forma.nombre}</p>
                        <Pill tone={forma.activo ? "green" : "amber"}>
                          {forma.activo ? "Habilitada" : "Inhabilitada"}
                        </Pill>
                      </div>
                      <p style={styles.productMeta}>Forma del sistema #{forma.idFormaPago}</p>
                    </div>

                    <div style={{ width: "100%", maxWidth: 380 }}>
                      <SwitchCard
                        checked={Boolean(forma.activo)}
                        title={forma.activo ? "La ofrece el vendedor" : "No la ofrece"}
                        description="Aparece al elegir la forma de pago de su venta."
                        onChange={(checked) =>
                          setFormasVendedor((current) =>
                            current.map((item) =>
                              item.idFormaPago === forma.idFormaPago
                                ? { ...item, activo: checked }
                                : item
                            )
                          )
                        }
                      />
                    </div>
                  </div>
                ))}
              </div>

              <div style={styles.inlineActions}>
                <button type="button" style={styles.primaryBtn} onClick={guardarFormasVendedor}>
                  Guardar formas del vendedor
                </button>
              </div>
            </article>
          </section>
        </>
      )}

      {activeSection === "fidelidad" && (
        <>
          <SectionHeader
            title="Programas de fidelidad"
            subtitle="Activa los programas que la app del autoservicio ofrece al cliente. Los que esten inactivos no aparecen en el mapeo."
          />
          <section style={styles.productsLayout}>
            <article style={styles.card}>
              <div style={styles.cardTop}>
                <div>
                  <div style={styles.cardTitleWrap}>
                    <h4 style={styles.cardTitle}>Programas</h4>
                    <Pill tone="blue">{plural(fidelidad.length, "item", "items")}</Pill>
                    <Pill tone={fidelidad.some((item) => item.activo) ? "green" : "amber"}>
                      {plural(fidelidad.filter((item) => item.activo).length, "activo", "activos")}
                    </Pill>
                  </div>
                  <p style={styles.cardMeta}>
                    El numero de cada programa es fijo y es el que usa la app para consultar y acumular.
                  </p>
                </div>
              </div>

              <div style={styles.productGrid}>
                {fidelidad.length === 0 && (
                  <div style={styles.emptyInlineState}>
                    <p style={styles.emptyInlineTitle}>No hay programas disponibles</p>
                    <p style={styles.emptyInlineText}>
                      El servicio no entrego la lista de programas de fidelidad.
                    </p>
                  </div>
                )}

                {fidelidad.map((programa) => (
                  <div
                    key={programa.idFidelidad}
                    className="cfg-product-item"
                    style={styles.productItem}
                  >
                    <div>
                      <div style={styles.cardTitleWrap}>
                        <p style={styles.productTitle}>{programa.nombre}</p>
                        <Pill tone={programa.activo ? "green" : "amber"}>
                          {programa.activo ? "Activo" : "Inactivo"}
                        </Pill>
                      </div>
                      <p style={styles.productMeta}>Programa #{programa.idFidelidad}</p>
                    </div>

                    <div style={{ width: "100%", maxWidth: 380 }}>
                    <SwitchCard
                      checked={Boolean(programa.activo)}
                      title={programa.activo ? "Se ofrece" : "No se ofrece"}
                      description="Aparece en el mapeo que recibe la app."
                      onChange={(checked) =>
                        setFidelidad((current) =>
                          current.map((item) =>
                            item.idFidelidad === programa.idFidelidad
                              ? { ...item, activo: checked }
                              : item
                          )
                        )
                      }
                    />
                    </div>
                  </div>
                ))}
              </div>

              <div style={styles.inlineActions}>
                <button type="button" style={styles.primaryBtn} onClick={guardarFidelidad}>
                  Guardar programas
                </button>
              </div>
            </article>
          </section>
        </>
      )}
    </div>
  );
}

// Tipos de identificador de cliente del autoservicio, en el orden de las banderas "iButton|Teclado|Placa"
const IDENTIFICADORES = [
  { label: "iButton", icon: "ibutton", description: "Llave que el cliente acerca al lector." },
  { label: "Teclado", icon: "teclado", description: "Codigo y contrasena que digita el cliente." },
  { label: "Placa", icon: "placa", description: "Se busca por la placa del vehiculo." },
];

function IdentificadorIcon({ name }) {
  const common = {
    width: 22,
    height: 22,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.8,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    "aria-hidden": true,
  };

  if (name === "ibutton") {
    return (
      <svg {...common}>
        <circle cx="12" cy="12" r="8" />
        <circle cx="12" cy="12" r="3.2" />
      </svg>
    );
  }
  if (name === "teclado") {
    return (
      <svg {...common}>
        <rect x="3" y="6" width="18" height="12" rx="2.5" />
        <path d="M7 10h.01M11 10h.01M15 10h.01M7 14h10" />
      </svg>
    );
  }
  return (
    <svg {...common}>
      <rect x="3" y="7" width="18" height="10" rx="2.5" />
      <path d="M7 12h.01M10.5 12h6" />
    </svg>
  );
}

// Interruptor con titulo y descripcion
function SwitchCard({ checked, onChange, title, description }) {
  return (
    <label className={`cfg-switch-card${checked ? " is-on" : ""}`}>
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
      />
      <span className="cfg-switch-track">
        <span className="cfg-switch-thumb" />
      </span>
      <span className="cfg-card-text">
        <strong>{title}</strong>
        <small>{description}</small>
      </span>
    </label>
  );
}

// Opcion que se marca o desmarca con icono y descripcion
function ChoiceCard({ checked, onChange, title, description, icon }) {
  return (
    <label className={`cfg-choice-card${checked ? " is-on" : ""}`}>
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
      />
      <span className="cfg-choice-icon">
        <IdentificadorIcon name={icon} />
      </span>
      <span className="cfg-card-text">
        <strong>{title}</strong>
        <small>{description}</small>
      </span>
      <span className="cfg-choice-check" aria-hidden="true">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M5 12.5l4.5 4.5L19 7.5" />
        </svg>
      </span>
    </label>
  );
}

function parseIdentificadores(valor) {
  const partes = String(valor || "1|1|1").split("|");
  return IDENTIFICADORES.map((_, index) => (partes[index] ?? "1").trim() === "1");
}

function buildIdentificadores(banderas) {
  return banderas.map((activo) => (activo ? "1" : "0")).join("|");
}

function SectionHeader({ title, subtitle }) {
  return (
    <div style={styles.sectionHeader}>
      <h4 style={styles.sectionTitle}>{title}</h4>
      <p style={styles.sectionText}>{subtitle}</p>
    </div>
  );
}

function SectionToggle({ label, description, icon, badge, active, onClick }) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      className={`cfg-nav-card${active ? " is-active" : ""}`}
      onClick={onClick}
    >
      <span className="cfg-nav-icon">
        <IconoSeccion name={icon} />
      </span>
      <span className="cfg-nav-text">
        <strong>{label}</strong>
        <small>{description}</small>
      </span>
      {badge && <span className={`cfg-nav-badge ${badge.tono}`}>{badge.texto}</span>}
    </button>
  );
}

function IconoSeccion({ name }) {
  const comunes = {
    width: 22,
    height: 22,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.8,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    "aria-hidden": true,
  };

  switch (name) {
    case "sistema":
      return (
        <svg {...comunes}>
          <circle cx="12" cy="12" r="3" />
          <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" />
        </svg>
      );
    case "marcaciones":
      return (
        <svg {...comunes}>
          <path d="M13 2 4 14h7l-1 8 9-12h-7z" />
        </svg>
      );
    case "equipos":
      return (
        <svg {...comunes}>
          <rect x="3" y="4" width="18" height="12" rx="2.5" />
          <path d="M8 20h8M12 16v4" />
        </svg>
      );
    case "posiciones":
      return (
        <svg {...comunes}>
          <rect x="3" y="3" width="7.5" height="7.5" rx="1.8" />
          <rect x="13.5" y="3" width="7.5" height="7.5" rx="1.8" />
          <rect x="3" y="13.5" width="7.5" height="7.5" rx="1.8" />
          <rect x="13.5" y="13.5" width="7.5" height="7.5" rx="1.8" />
        </svg>
      );
    case "mangueras":
      return (
        <svg {...comunes}>
          <path d="M12 3s6 6.2 6 10.5A6 6 0 0 1 6 13.5C6 9.2 12 3 12 3z" />
        </svg>
      );
    case "productos":
      return (
        <svg {...comunes}>
          <path d="M21 8 12 3 3 8v8l9 5 9-5z" />
          <path d="m3 8 9 5 9-5M12 13v8" />
        </svg>
      );
    case "pagos":
      return (
        <svg {...comunes}>
          <rect x="2.5" y="5" width="19" height="14" rx="2.5" />
          <path d="M2.5 10h19M6.5 15h4" />
        </svg>
      );
    default:
      return (
        <svg {...comunes}>
          <path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z" />
        </svg>
      );
  }
}

function DispensadorFilter({ value, onChange, dispensadores, helper }) {
  return (
    <section className="cfg-filter-bar" style={styles.filterBar}>
      <div>
        <p style={styles.filterTitle}>Filtrar por dispensador</p>
        <p style={styles.filterText}>{helper}</p>
      </div>

      <label style={styles.filterControl}>
        <span style={styles.fieldLabel}>Dispensador</span>
        <select
          style={styles.select}
          value={value}
          onChange={(event) => onChange(event.target.value)}
        >
          <option value="all">Todos</option>
          {dispensadores.map((dispensador) => (
            <option
              key={dispensador.idDispensador}
              value={String(dispensador.idDispensador)}
            >
              Dispensador {dispensador.idDispensador}
            </option>
          ))}
        </select>
      </label>
    </section>
  );
}

// Las tarjetas "pendiente" se ponen verdes en cero y ambar si falta algo
function StatCard({ label, value, nota, tone = "blue", pendiente = false }) {
  const estado = pendiente ? (value === 0 ? "ok" : "pend") : tone;
  const texto = pendiente ? (value === 0 ? "Al dia" : "Por configurar") : nota;

  return (
    <div className={`cfg-stat cfg-stat-${estado}`}>
      <p className="cfg-stat-label">{label}</p>
      <p className="cfg-stat-value">{value}</p>
      <p className="cfg-stat-note">{texto}</p>
    </div>
  );
}

function RefreshIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 16 16" fill="none">
      <path d="M13.5 8A5.5 5.5 0 1 1 8 2.5c1.8 0 3.4.87 4.4 2.2" stroke="currentColor" strokeWidth="1.35" strokeLinecap="round" />
      <path d="M12 2v3h-3" stroke="currentColor" strokeWidth="1.35" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function getScreenKey(idPosicion) {
  return `screen-${idPosicion}`;
}

function padMarcaciones(values) {
  const next = (values ?? []).slice(0, 3).map((value) => Number(value || 0));
  while (next.length < 3) {
    next.push(0);
  }
  return next;
}

function getHoseKey(idPosicionGrado) {
  return `hose-${idPosicionGrado}`;
}

function getColorPreview(value) {
  if (!value) return "";
  if (/^#[0-9a-fA-F]{6}$/.test(value)) return value;
  if (/^#[0-9a-fA-F]{8}$/.test(value)) return `#${value.slice(3)}`;
  return "";
}

function normalizeHexForPicker(value) {
  return getColorPreview(value) || "#d9dee7";
}

function pickerToStoredHex(pickerHex, previousValue) {
  if (/^#[0-9a-fA-F]{8}$/.test(previousValue || "")) {
    return `#FF${pickerHex.slice(1).toUpperCase()}`;
  }
  return pickerHex.toUpperCase();
}

function formatNumber(value) {
  return new Intl.NumberFormat("es-CO").format(Number(value || 0));
}

const PRESET_MAX = 999999;

function getPresetBounds(precio) {
  const min = Math.max(1, Math.round(Number(precio || 0) * 0.1) + 1);
  return { min, max: PRESET_MAX };
}

function clampPreset(value, precio) {
  const { min, max } = getPresetBounds(precio);
  const parsed = Number(value || 0);
  return Math.min(max, Math.max(min, parsed));
}

function sanitizeText(value) {
  return (value || "").replace(/[^a-zA-Z0-9 ._:-]/g, "").slice(0, 60);
}

function sanitizeHexColor(value) {
  return (value || "").replace(/[^0-9a-fA-F#]/g, "").slice(0, 9);
}

function clampNumberInRange(value, min, max) {
  const parsed = Number(value || 0);
  if (Number.isNaN(parsed)) return min;
  return Math.min(max, Math.max(min, parsed));
}

const styles = {
  wrap: {
    display: "flex",
    flexDirection: "column",
    gap: 18,
  },
  stateWrap: {
    minHeight: 320,
    display: "grid",
    placeItems: "center",
    alignContent: "center",
    gap: 14,
  },
  spinner: {
    width: 30,
    height: 30,
    border: "3px solid rgba(18,31,53,0.12)",
    borderTopColor: "var(--accent-strong)",
    borderRadius: "50%",
    animation: "spin 0.8s linear infinite",
  },
  stateText: {
    fontSize: 14,
    color: "var(--text-secondary)",
  },
  errorText: {
    color: "var(--danger)",
    fontSize: 14,
  },
  retryBtn: {
    padding: "12px 18px",
    fontSize: 13,
    fontWeight: 700,
    color: "#fff",
    border: "none",
    borderRadius: 14,
    cursor: "pointer",
    background:
      "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
  },
  header: {
    display: "flex",
    justifyContent: "space-between",
    gap: 18,
    alignItems: "center",
    padding: "26px 28px",
    borderRadius: 26,
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.88) 0%, rgba(246,249,252,0.96) 100%)",
    border: "1px solid rgba(18,31,53,0.08)",
    boxShadow: "0 18px 30px rgba(26, 44, 73, 0.06)",
  },
  headerTop: {
    display: "flex",
    alignItems: "center",
    gap: 10,
    flexWrap: "wrap",
    marginBottom: 12,
  },
  headerCaption: {
    fontSize: 11,
    fontWeight: 700,
    letterSpacing: "0.1em",
    textTransform: "uppercase",
    color: "var(--text-muted)",
  },
  title: {
    fontSize: 30,
    lineHeight: 1.05,
    color: "var(--text-primary)",
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    color: "var(--text-secondary)",
    lineHeight: 1.6,
    maxWidth: 720,
  },
  refreshBtn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 10,
    padding: "12px 16px",
    borderRadius: 16,
    border: "1px solid rgba(41,112,255,0.12)",
    background: "rgba(41,112,255,0.08)",
    color: "var(--accent-strong)",
    fontWeight: 700,
    cursor: "pointer",
    flexShrink: 0,
  },
  groupCard: {
    padding: 18,
    borderRadius: 26,
    border: "1px solid rgba(18,31,53,0.08)",
    background:
      "linear-gradient(180deg, rgba(237,243,250,0.75) 0%, rgba(247,250,252,0.98) 100%)",
    boxShadow: "0 16px 26px rgba(26, 44, 73, 0.05)",
    display: "grid",
    gap: 16,
  },
  groupHeader: {
    paddingBottom: 2,
  },
  groupHeaderLead: {
    display: "flex",
    alignItems: "center",
    gap: 14,
  },
  groupBody: {
    display: "grid",
    gap: 14,
  },
  sectionHeader: {
    paddingTop: 8,
  },
  filterBar: {
    padding: "18px 20px",
    borderRadius: 22,
    border: "1px solid rgba(18,31,53,0.08)",
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.94) 0%, rgba(246,249,252,0.98) 100%)",
    boxShadow: "0 14px 24px rgba(26, 44, 73, 0.05)",
  },
  filterTitle: {
    fontSize: 15,
    fontWeight: 700,
    color: "var(--text-primary)",
    marginBottom: 6,
  },
  filterText: {
    fontSize: 13,
    color: "var(--text-secondary)",
    lineHeight: 1.6,
  },
  filterControl: {
    display: "grid",
    gap: 7,
  },
  sectionTitle: {
    fontSize: 22,
    color: "var(--text-primary)",
    marginBottom: 6,
  },
  sectionText: {
    fontSize: 14,
    color: "var(--text-secondary)",
    lineHeight: 1.6,
  },
  cardList: {
    display: "grid",
    gap: 14,
  },
  card: {
    padding: 20,
    borderRadius: 24,
    border: "1px solid rgba(18,31,53,0.08)",
    background:
      "linear-gradient(180deg, rgba(255,255,255,0.95) 0%, rgba(247,250,252,0.98) 100%)",
    boxShadow: "0 16px 26px rgba(26, 44, 73, 0.06)",
    display: "grid",
    gap: 16,
  },
  cardTop: {
    display: "flex",
    justifyContent: "space-between",
    gap: 12,
    alignItems: "center",
  },
  cardLead: {
    display: "flex",
    gap: 14,
    alignItems: "center",
  },
  cardIndex: {
    width: 46,
    height: 46,
    borderRadius: 16,
    display: "grid",
    placeItems: "center",
    background:
      "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
    color: "#fff",
    fontSize: 16,
    fontWeight: 700,
    flexShrink: 0,
  },
  cardTitleWrap: {
    display: "flex",
    alignItems: "center",
    gap: 10,
    flexWrap: "wrap",
    marginBottom: 6,
  },
  cardTitle: {
    fontSize: 18,
    color: "var(--text-primary)",
  },
  cardMeta: {
    fontSize: 13,
    color: "var(--text-secondary)",
  },
  infoBox: {
    padding: 16,
    borderRadius: 18,
    border: "1px solid rgba(36,118,86,0.12)",
    background: "rgba(36,118,86,0.06)",
    display: "grid",
    gridTemplateColumns: "minmax(0, 1fr) auto",
    gap: 12,
    alignItems: "center",
  },
  deviceInfoGrid: {},
  infoLabel: {
    fontSize: 11,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.08em",
    color: "var(--text-muted)",
    marginBottom: 8,
  },
  infoValue: {
    fontSize: 20,
    fontWeight: 700,
    color: "var(--text-primary)",
  },
  editorBox: {
    padding: 16,
    borderRadius: 18,
    border: "1px dashed rgba(222,139,28,0.32)",
    background: "rgba(255,249,240,0.88)",
    display: "grid",
    gap: 14,
  },
  editorTitle: {
    fontSize: 15,
    fontWeight: 700,
    color: "var(--text-primary)",
  },
  deviceFields: {},
  formGrid: {},
  field: {
    display: "grid",
    gap: 7,
  },
  fieldLabel: {
    fontSize: 11,
    fontWeight: 700,
    textTransform: "uppercase",
    letterSpacing: "0.08em",
    color: "var(--text-muted)",
  },
  fieldHint: {
    fontSize: 11,
    color: "var(--text-muted)",
  },
  groupLabel: {
    fontSize: 12,
    fontWeight: 700,
    color: "var(--text-secondary)",
    marginBottom: 10,
  },
  pillRow: {
    display: "flex",
    gap: 8,
    flexWrap: "wrap",
  },
  input: {
    width: "100%",
    padding: "14px 15px",
    borderRadius: 14,
    border: "1px solid var(--border-strong)",
    background: "#fff",
    color: "var(--text-primary)",
    fontSize: 14,
    outline: "none",
  },
  select: {
    width: "100%",
    padding: "14px 15px",
    borderRadius: 14,
    border: "1px solid var(--border-strong)",
    background: "#fff",
    color: "var(--text-primary)",
    fontSize: 14,
    outline: "none",
    appearance: "none",
  },
  primaryBtn: {
    minHeight: 42,
    padding: "0 18px",
    border: "none",
    borderRadius: 14,
    background:
      "linear-gradient(135deg, rgba(41,112,255,1) 0%, rgba(27,82,187,1) 100%)",
    color: "#fff",
    fontSize: 13,
    fontWeight: 700,
    cursor: "pointer",
  },
  secondaryBtn: {
    padding: "11px 14px",
    borderRadius: 12,
    border: "1px solid rgba(41,112,255,0.12)",
    background: "#fff",
    color: "var(--accent-strong)",
    fontSize: 13,
    fontWeight: 700,
    cursor: "pointer",
  },
  inlineActions: {
    display: "flex",
    justifyContent: "flex-end",
    gap: 10,
    flexWrap: "wrap",
  },
  cancelBtn: {
    padding: 0,
    border: "none",
    background: "transparent",
    color: "var(--text-secondary)",
    fontSize: 13,
    fontWeight: 700,
    cursor: "pointer",
  },
  hoseGrid: {
    display: "grid",
    gap: 12,
  },
  hoseItem: {
    padding: 14,
    borderRadius: 18,
    border: "1px solid rgba(18,31,53,0.08)",
    background: "rgba(243,247,251,0.88)",
    display: "grid",
    gap: 12,
  },
  hoseHeader: {
    display: "flex",
    justifyContent: "space-between",
    gap: 12,
    alignItems: "center",
  },
  hoseTitle: {
    fontSize: 15,
    fontWeight: 700,
    color: "var(--text-primary)",
    marginBottom: 4,
  },
  hoseMeta: {
    fontSize: 12,
    color: "var(--text-secondary)",
  },
  hoseFields: {
    display: "grid",
    gridTemplateColumns: "120px minmax(0, 1fr)",
    gap: 12,
  },
  colorField: {
    display: "grid",
    gridTemplateColumns: "56px minmax(0, 1fr)",
    gap: 10,
    alignItems: "center",
  },
  colorInput: {
    width: 56,
    height: 44,
    borderRadius: 12,
    border: "1px solid var(--border-strong)",
    background: "#fff",
    padding: 4,
    cursor: "pointer",
  },
  colorSwatch: {
    width: 24,
    height: 24,
    borderRadius: 999,
    border: "1px solid rgba(18,31,53,0.1)",
    flexShrink: 0,
  },
  productsLayout: {
    display: "grid",
    gap: 14,
  },
  productGrid: {
    display: "grid",
    gap: 12,
  },
  productItem: {
    padding: 14,
    borderRadius: 18,
    border: "1px solid rgba(18,31,53,0.08)",
    background: "rgba(243,247,251,0.88)",
  },
  productTitle: {
    fontSize: 15,
    fontWeight: 700,
    color: "var(--text-primary)",
    marginBottom: 4,
  },
  productMeta: {
    fontSize: 12,
    color: "var(--text-secondary)",
  },
  paymentFields: {},
  marcacionesGrid: {},
  emptyInlineState: {
    padding: 18,
    borderRadius: 18,
    border: "1px dashed rgba(18,31,53,0.14)",
    background: "rgba(243,247,251,0.72)",
    display: "grid",
    gap: 6,
  },
  emptyInlineTitle: {
    fontSize: 15,
    fontWeight: 700,
    color: "var(--text-primary)",
  },
  emptyInlineText: {
    fontSize: 13,
    color: "var(--text-secondary)",
    lineHeight: 1.6,
  },
  pill: {
    display: "inline-flex",
    alignItems: "center",
    padding: "7px 10px",
    borderRadius: 999,
    fontSize: 11,
    fontWeight: 700,
    letterSpacing: "0.06em",
    textTransform: "uppercase",
  },
};
