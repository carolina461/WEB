#!/usr/bin/env node
/**
 * build-blog.js — Asesoría CT
 * Lee todos los .md en content/blog/, regenera:
 *   - js/blog-data.js       (catálogo de tarjetas)
 *   - js/blog-engine.js     (contenido completo + parser Markdown)
 *   - content/blog-index.json  (índice JSON de respaldo)
 *   - sitemap.xml
 */

const fs   = require('fs');
const path = require('path');

const ROOT        = path.resolve(__dirname, '..');
const BLOG_DIR    = path.join(ROOT, 'content', 'blog');
const DATA_JS     = path.join(ROOT, 'js', 'blog-data.js');
const ENGINE_JS   = path.join(ROOT, 'js', 'blog-engine.js');
const INDEX_JSON  = path.join(ROOT, 'content', 'blog-index.json');
const SITEMAP_XML = path.join(ROOT, 'sitemap.xml');
const BASE_URL    = 'https://asesoriact.com';
const TODAY       = new Date().toISOString().slice(0, 10);

// ─── Helpers ──────────────────────────────────────────────────────────────────

function parseFrontMatter(raw) {
  const result = { title: '', slug: '', date: '', category: '', summary: '', body: '' };
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) {
    result.body = raw.trim();
    return result;
  }
  const yamlBlock = match[1];
  result.body = match[2].trim();

  // Parse YAML line by line (simple, no library needed)
  let currentKey = null;
  let multilineValue = '';
  const lines = yamlBlock.split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Detect key: value or key: | (multiline)
    const keyMatch = line.match(/^(\w+):\s*(.*)/);
    if (keyMatch) {
      if (currentKey && multilineValue) {
        result[currentKey] = multilineValue.trim().replace(/^["']|["']$/g, '');
        multilineValue = '';
      }
      currentKey = keyMatch[1];
      let val = keyMatch[2].trim();

      // Quoted string with possible continuation
      if ((val.startsWith('"') || val.startsWith("'")) && !val.endsWith(val[0])) {
        // Multi-line quoted value
        const quote = val[0];
        multilineValue = val.slice(1);
        // Look ahead for continuation lines (indented)
        while (i + 1 < lines.length && lines[i + 1].match(/^\s+/)) {
          i++;
          multilineValue += ' ' + lines[i].trim();
        }
        result[currentKey] = multilineValue.replace(new RegExp(quote + '$'), '').trim();
        currentKey = null;
        multilineValue = '';
      } else {
        result[currentKey] = val.replace(/^["']|["']$/g, '');
        currentKey = null;
      }
    } else if (currentKey && line.match(/^\s+/)) {
      // Continuation of a multi-line value
      multilineValue += ' ' + line.trim();
    }
  }
  if (currentKey && multilineValue) {
    result[currentKey] = multilineValue.trim().replace(/^["']|["']$/g, '');
  }
  return result;
}

function escapeTemplateLiteral(str) {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/`/g, '\\`')
    .replace(/\$\{/g, '\\${');
}

// ─── Load & parse all .md files ───────────────────────────────────────────────

const mdFiles = fs.readdirSync(BLOG_DIR)
  .filter(f => f.endsWith('.md'))
  .map(f => {
    const raw = fs.readFileSync(path.join(BLOG_DIR, f), 'utf8');
    const data = parseFrontMatter(raw);
    if (!data.slug) {
      data.slug = path.basename(f, '.md');
    }
    if (!data.date) {
      data.date = TODAY;
    }
    data.file = `content/blog/${f}`;
    return data;
  })
  .sort((a, b) => (b.date > a.date ? 1 : b.date < a.date ? -1 : 0)); // newest first

console.log(`Found ${mdFiles.length} articles:`);
mdFiles.forEach(a => console.log(`  • [${a.date}] ${a.slug}`));

// ─── 1. js/blog-data.js ───────────────────────────────────────────────────────

const blogDataEntries = mdFiles.map(a => `  {
    title: ${JSON.stringify(a.title)},
    slug: ${JSON.stringify(a.slug)},
    date: ${JSON.stringify(a.date)},
    category: ${JSON.stringify(a.category)},
    summary: ${JSON.stringify(a.summary)},
    file: ${JSON.stringify(a.file)}
  }`).join(',\n');

const blogDataJS = `/**
 * Asesoría CT - Sistema Central de Artículos del Blog
 * ⚠️  ARCHIVO GENERADO AUTOMÁTICAMENTE por scripts/build-blog.js
 *     No editar a mano. Ejecutar: node scripts/build-blog.js
 */

window.BLOG_DATA = [
${blogDataEntries}
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
`;

fs.writeFileSync(DATA_JS, blogDataJS, 'utf8');
console.log('✅  js/blog-data.js actualizado');

// ─── 2. js/blog-engine.js ─────────────────────────────────────────────────────

const articleEntries = mdFiles.map(a => {
  const bodyEscaped = escapeTemplateLiteral(a.body);
  return `  ${JSON.stringify(a.slug)}: {
    title: ${JSON.stringify(a.title)},
    slug: ${JSON.stringify(a.slug)},
    date: ${JSON.stringify(a.date)},
    category: ${JSON.stringify(a.category)},
    summary: ${JSON.stringify(a.summary)},
    body: \`${bodyEscaped}\`
  }`;
}).join(',\n\n');

const blogEngineJS = `/**
 * Asesoría CT - Motor de Artículos y Renderizador Markdown
 * ⚠️  ARCHIVO GENERADO AUTOMÁTICAMENTE por scripts/build-blog.js
 *     No editar a mano. Ejecutar: node scripts/build-blog.js
 */

window.BLOG_ARTICLES_DATA = {
${articleEntries}
};

/**
 * Función ligera para parsear Markdown a HTML
 */
function parseMarkdownToHTML(markdownText) {
  if (!markdownText) return '';

  let html = markdownText;

  // Normalizar saltos de línea
  html = html.replace(/\\r\\n/g, '\\n');

  // Separadores horizontales
  html = html.replace(/^(?:---|\\*\\*\\*|___)\\s*$/gm, '<hr>');

  // Encabezados
  html = html.replace(/^#### (.*?)$/gm, '<h4>$1</h4>');
  html = html.replace(/^### (.*?)$/gm, '<h3>$1</h3>');
  html = html.replace(/^## (.*?)$/gm, '<h2>$1</h2>');
  html = html.replace(/^# (.*?)$/gm, '<h1>$1</h1>');

  // Negrita e itálica
  html = html.replace(/\\*\\*\\*(.*?)\\*\\*\\*/g, '<strong><em>$1</em></strong>');
  html = html.replace(/\\*\\*(.*?)\\*\\*/g, '<strong>$1</strong>');
  html = html.replace(/\\*(.*?)\\*/g, '<em>$1</em>');

  // Código en línea
  html = html.replace(/\`([^\`]+)\`/g, '<code>$1</code>');

  // Enlaces
  html = html.replace(/\\[([^\\]]+)\\]\\(([^)]+)\\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');

  // Listas ordenadas y desordenadas
  html = html.replace(/^\\s*\\d+\\.\\s+(.*?)$/gm, '<li class="blog-ol-item">$1</li>');
  html = html.replace(/^\\s*[-*]\\s+(.*?)$/gm, '<li class="blog-ul-item">$1</li>');

  html = html.replace(/((?:<li class="blog-ol-item">.*?<\\/li>\\s*)+)/g, '<ol>$1</ol>');
  html = html.replace(/((?:<li class="blog-ul-item">.*?<\\/li>\\s*)+)/g, '<ul>$1</ul>');

  html = html.replace(/ class="blog-ol-item"/g, '').replace(/ class="blog-ul-item"/g, '');

  // Párrafos
  const blocks = html.split(/\\n{2,}/);
  html = blocks.map(block => {
    block = block.trim();
    if (!block) return '';
    if (/^<(?:h[1-6]|ul|ol|li|hr|div|blockquote|p)/i.test(block)) {
      return block;
    }
    return \`<p>\${block.replace(/\\n/g, '<br>')}</p>\`;
  }).filter(Boolean).join('\\n\\n');

  return html;
}

window.parseMarkdownToHTML = parseMarkdownToHTML;
`;

fs.writeFileSync(ENGINE_JS, blogEngineJS, 'utf8');
console.log('✅  js/blog-engine.js actualizado');

// ─── 3. content/blog-index.json ───────────────────────────────────────────────

const indexJson = mdFiles.map(a => ({
  title: a.title,
  slug: a.slug,
  date: a.date,
  category: a.category,
  summary: a.summary,
  file: a.file
}));

fs.writeFileSync(INDEX_JSON, JSON.stringify(indexJson, null, 2), 'utf8');
console.log('✅  content/blog-index.json actualizado');

// ─── 4. sitemap.xml ───────────────────────────────────────────────────────────

const blogUrls = mdFiles.map(a => `  <url>
    <loc>${BASE_URL}/blog/${a.slug}</loc>
    <lastmod>${a.date}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>`).join('\n');

const sitemapXml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <!-- Paginas Principales -->
  <url>
    <loc>${BASE_URL}/</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>${BASE_URL}/servicios.html</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>${BASE_URL}/quienes-somos.html</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>${BASE_URL}/contacto.html</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>${BASE_URL}/blog.html</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.9</priority>
  </url>

  <!-- Articulos del Blog -->
${blogUrls}

  <!-- Paginas Legales -->
  <url>
    <loc>${BASE_URL}/terminos-y-condiciones.html</loc>
    <lastmod>2026-11-14</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
  <url>
    <loc>${BASE_URL}/politica-de-privacidad.html</loc>
    <lastmod>2026-11-14</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
  <url>
    <loc>${BASE_URL}/aviso-legal.html</loc>
    <lastmod>2026-11-14</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
</urlset>
`;

fs.writeFileSync(SITEMAP_XML, sitemapXml, 'utf8');
console.log('✅  sitemap.xml actualizado');

console.log(`\n🎉 Build completo: ${mdFiles.length} artículos procesados.`);
