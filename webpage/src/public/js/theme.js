// Aplica los colores de marca de la estación (traídos del API) como variables CSS.
(async function applyTheme() {
  try {
    const res = await fetch('/api/nsx-autoservice/page/theme');
    const { colors } = await res.json();
    if (!Array.isArray(colors)) return;

    const root = document.documentElement.style;
    colors.forEach((color, i) => root.setProperty(`--brand-${i + 1}`, color));
  } catch (error) {
    // Si falla, se quedan los colores por defecto definidos en theme.css
  }
})();
