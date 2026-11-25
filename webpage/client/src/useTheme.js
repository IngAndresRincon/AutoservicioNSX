import { useEffect } from 'react';

// Trae los colores de marca de la estación y los aplica como variables CSS.
export function useTheme() {
  useEffect(() => {
    fetch('/api/nsx-autoservice/page/theme')
      .then((res) => res.json())
      .then(({ colors }) => {
        if (!Array.isArray(colors)) return;
        colors.forEach((color, i) =>
          document.documentElement.style.setProperty(`--brand-${i + 1}`, color)
        );
      })
      .catch(() => {
        // Se quedan los colores por defecto definidos en index.css
      });
  }, []);
}
