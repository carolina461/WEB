/**
 * Asesoría CT - Sistema Central de Artículos del Blog
 * Gestiona el catálogo de artículos, almacenamiento y renderizado.
 */

window.BLOG_DATA = [
  {
    title: "Cómo evitar sanciones costosas de la DIAN por errores en facturación electrónica",
    slug: "evitar-sanciones-dian-facturacion-electronica",
    date: "2026-11-10",
    category: "DIAN",
    summary: "Conoce los errores más comunes al emitir facturas electrónicas y aprende a blindar tu negocio ante multas y cierres de la DIAN.",
    file: "content/blog/evitar-sanciones-dian-facturacion-electronica.md"
  },
  {
    title: "Nómina electrónica y aportes a seguridad social: guía para evitar requerimientos de la UGPP",
    slug: "nomina-electronica-seguridad-social-ugpp",
    date: "2026-11-05",
    category: "Nómina y Laboral",
    summary: "Aprende a reportar correctamente tu nómina electrónica y blindar tu empresa frente a costosas auditorías y sanciones de la UGPP.",
    file: "content/blog/nomina-electronica-seguridad-social-ugpp.md"
  },
  {
    title: "Planeación del IVA bimestral vs. cuatrimestral: claves para proteger tu flujo de caja",
    slug: "planeacion-iva-bimestral-cuatrimestral-flujo-caja",
    date: "2026-10-28",
    category: "Impuestos",
    summary: "Descubre cómo elegir el periodo fiscal de IVA correcto y optimizar tus retenciones en la fuente para no desfinanciar tu negocio.",
    file: "content/blog/planeacion-iva-bimestral-cuatrimestral-flujo-caja.md"
  }
];

// Función para obtener artículos ordenados por fecha descendente
function getBlogArticles() {
  return [...window.BLOG_DATA].sort((a, b) => new Date(b.date) - new Date(a.date));
}

// Función para formatear fechas en español
function formatBlogDate(dateStr) {
  if (!dateStr) return '';
  const parts = dateStr.split('-');
  if (parts.length === 3) {
    const year = parts[0];
    const month = parseInt(parts[1], 10) - 1;
    const day = parseInt(parts[2], 10);
    const date = new Date(year, month, day);
    return date.toLocaleDateString('es-CO', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  }
  return dateStr;
}

// Exportar globalmente
window.getBlogArticles = getBlogArticles;
window.formatBlogDate = formatBlogDate;
