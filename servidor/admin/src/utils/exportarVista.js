// Exporta una vista de la pagina a PDF (ventana de impresion) o a JPG, sin librerias.
// Las dos salidas copian los estilos calculados a un clon del nodo, asi que no dependen del CSS de la pagina.

const ESCALA_IMAGEN = 2;
const ANCHO_PAGINA_PX = 1040; // A4 horizontal con margenes de 10 mm
const FUENTES_URL =
  "https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap";

// En los textos sueltos no se fija el tamano: en la imagen la tipografia puede ser otra y el texto no cabria en el ancho de pantalla
const TAGS_TEXTO = new Set(["SPAN", "STRONG", "P", "SMALL", "B", "EM", "I", "LABEL", "H1", "H2", "H3", "H4", "H5", "H6"]);
const PROPIEDADES_TAMANO = new Set([
  "width", "height", "min-width", "max-width", "min-height", "max-height",
  "inline-size", "block-size", "min-inline-size", "max-inline-size", "min-block-size", "max-block-size",
]);

function esTextoSuelto(elemento) {
  return (
    TAGS_TEXTO.has(elemento.tagName) &&
    elemento.children.length === 0 &&
    elemento.textContent.trim() !== ""
  );
}

function copiarEstilos(origen, destino) {
  const calculado = window.getComputedStyle(origen);
  const sinTamano = esTextoSuelto(origen);
  let css = "";
  for (let i = 0; i < calculado.length; i += 1) {
    const propiedad = calculado[i];
    if (sinTamano && PROPIEDADES_TAMANO.has(propiedad)) continue;
    css += `${propiedad}:${calculado.getPropertyValue(propiedad)};`;
  }
  destino.setAttribute("style", css);

  const hijosOrigen = origen.children;
  const hijosDestino = destino.children;
  for (let i = 0; i < hijosOrigen.length; i += 1) {
    copiarEstilos(hijosOrigen[i], hijosDestino[i]);
  }
}

// Clon del nodo con los estilos de ahora y sin lo marcado como .rpt-no-export (botones, buscador, paginador)
function prepararClon(nodo) {
  const clon = nodo.cloneNode(true);
  copiarEstilos(nodo, clon);
  clon.querySelectorAll(".rpt-no-export").forEach((elemento) => elemento.remove());
  clon.style.margin = "0";
  return clon;
}

function cargarImagen(url) {
  return new Promise((resolve, reject) => {
    const imagen = new Image();
    imagen.onload = () => resolve(imagen);
    imagen.onerror = () => reject(new Error("No fue posible generar la imagen."));
    imagen.src = url;
  });
}

// Genera el JPG de un nodo y lo devuelve como Blob (no lo descarga: la pagina muestra primero una vista previa)
export async function nodoAJpg(nodo, { fondo = "#eef3f8" } = {}) {
  const ancho = Math.ceil(nodo.scrollWidth);
  const alto = Math.ceil(nodo.scrollHeight);

  const clon = prepararClon(nodo);
  clon.style.width = `${ancho}px`;

  const xhtml = new XMLSerializer().serializeToString(clon);
  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" width="${ancho}" height="${alto}">` +
    `<foreignObject x="0" y="0" width="100%" height="100%">${xhtml}</foreignObject></svg>`;

  const imagen = await cargarImagen(`data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`);

  const lienzo = document.createElement("canvas");
  lienzo.width = ancho * ESCALA_IMAGEN;
  lienzo.height = alto * ESCALA_IMAGEN;
  const contexto = lienzo.getContext("2d");
  contexto.fillStyle = fondo;
  contexto.fillRect(0, 0, lienzo.width, lienzo.height);
  contexto.scale(ESCALA_IMAGEN, ESCALA_IMAGEN);
  contexto.drawImage(imagen, 0, 0);

  const blob = await new Promise((resolve) => lienzo.toBlob(resolve, "image/jpeg", 0.92));
  if (!blob) throw new Error("No fue posible crear el archivo de imagen.");

  return blob;
}

// Abre una ventana limpia con la vista y lanza la impresion; el usuario elige "Guardar como PDF"
export function imprimirNodo(nodo, titulo) {
  const ventana = window.open("", "_blank");
  if (!ventana) {
    throw new Error("El navegador bloqueo la ventana del PDF. Permite las ventanas emergentes para este sitio.");
  }

  const ancho = Math.ceil(nodo.scrollWidth);
  const clon = prepararClon(nodo);
  const zoom = Math.min(1, ANCHO_PAGINA_PX / ancho);

  ventana.document.open();
  ventana.document.write(
    `<!doctype html><html lang="es"><head><meta charset="utf-8"><title>${titulo}</title>` +
      `<link rel="stylesheet" href="${FUENTES_URL}">` +
      `<style>@page{size:A4 landscape;margin:10mm}html,body{margin:0;background:#fff}` +
      `*{-webkit-print-color-adjust:exact;print-color-adjust:exact}` +
      `.rpt-card,.rpt-kpi{break-inside:avoid}</style></head>` +
      `<body><div style="zoom:${zoom};width:${ancho}px">${clon.outerHTML}</div></body></html>`
  );
  ventana.document.close();

  const imprimir = () => {
    ventana.focus();
    ventana.print();
  };
  const fuentes = ventana.document.fonts?.ready ?? Promise.resolve();
  Promise.race([fuentes, new Promise((resolve) => setTimeout(resolve, 1500))]).then(imprimir);
}
