#!/usr/bin/env pwsh
<#
  build-blog.ps1 — Asesoría CT
  Lee todos los .md en content/blog/, regenera:
    - js/blog-data.js        (catálogo de tarjetas)
    - js/blog-engine.js      (contenido completo + parser Markdown)
    - content/blog-index.json  (índice JSON)
    - sitemap.xml
#>

$ROOT       = Resolve-Path (Join-Path $PSScriptRoot "..")
$BLOG_DIR   = Join-Path $ROOT "content\blog"
$DATA_JS    = Join-Path $ROOT "js\blog-data.js"
$ENGINE_JS  = Join-Path $ROOT "js\blog-engine.js"
$INDEX_JSON = Join-Path $ROOT "content\blog-index.json"
$SITEMAP    = Join-Path $ROOT "sitemap.xml"
$BASE_URL   = "https://asesoriact.com"
$TODAY      = (Get-Date -Format "yyyy-MM-dd")

# ─── Helper: parse front matter ───────────────────────────────────────────────
function Parse-FrontMatter {
    param([string]$raw)
    $result = @{ title=''; slug=''; date=''; category=''; summary=''; body='' }

    if ($raw -match '(?s)^---\r?\n(.*?)\r?\n---\r?\n?(.*)$') {
        $yaml = $Matches[1]
        $result.body = $Matches[2].Trim()

        $lines = $yaml -split '\r?\n'
        $i = 0
        while ($i -lt $lines.Count) {
            $line = $lines[$i]
            if ($line -match '^(\w+):\s*(.*)') {
                $key = $Matches[1]
                $val = $Matches[2].Trim()

                # Collect multi-line values (continuation lines start with spaces)
                $j = $i + 1
                while ($j -lt $lines.Count -and $lines[$j] -match '^\s+') {
                    $val += ' ' + $lines[$j].Trim()
                    $j++
                }
                $i = $j

                # Strip surrounding quotes
                $val = $val -replace '^["\x27]|["\x27]$', ''
                $result[$key] = $val
            } else {
                $i++
            }
        }
    } else {
        $result.body = $raw.Trim()
    }
    return $result
}

# ─── Helper: escape JS template literal ───────────────────────────────────────
function Escape-TemplateLiteral {
    param([string]$s)
    $s = $s -replace '\\', '\\\\'
    $s = $s -replace '`', '\`'
    $s = $s -replace '\$\{', '\${'
    return $s
}

# ─── Load & parse all .md files ───────────────────────────────────────────────
$mdFiles = Get-ChildItem -Path $BLOG_DIR -Filter "*.md" | ForEach-Object {
    $raw  = Get-Content $_.FullName -Raw -Encoding UTF8
    $data = Parse-FrontMatter $raw
    if (-not $data.slug)  { $data.slug  = $_.BaseName }
    if (-not $data.date)  { $data.date  = $TODAY }
    $data.file = "content/blog/$($_.Name)"
    $data
} | Sort-Object { $_.date } -Descending

Write-Host "Found $($mdFiles.Count) articles:"
$mdFiles | ForEach-Object { Write-Host "  • [$($_.date)] $($_.slug)" }

# ─── 1. js/blog-data.js ───────────────────────────────────────────────────────
$dataEntries = ($mdFiles | ForEach-Object {
    $t = $_.title   -replace '\\', '\\\\'  -replace '"', '\"'
    $s = $_.slug    -replace '\\', '\\\\'  -replace '"', '\"'
    $d = $_.date    -replace '\\', '\\\\'  -replace '"', '\"'
    $c = $_.category -replace '\\', '\\\\'  -replace '"', '\"'
    $u = $_.summary -replace '\\', '\\\\'  -replace '"', '\"'
    $f = $_.file    -replace '\\', '\\\\'  -replace '"', '\"'
@"
  {
    title: "$t",
    slug: "$s",
    date: "$d",
    category: "$c",
    summary: "$u",
    file: "$f"
  }
"@
}) -join ",`n"

$blogDataJS = @"
/**
 * Asesoría CT - Sistema Central de Artículos del Blog
 * ⚠️  ARCHIVO GENERADO AUTOMÁTICAMENTE por scripts/build-blog.ps1
 *     No editar a mano. Ejecutar: scripts/build-blog.ps1
 */

window.BLOG_DATA = [
$dataEntries
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
    const year  = parts[0];
    const month = parseInt(parts[1], 10) - 1;
    const day   = parseInt(parts[2], 10);
    const date  = new Date(year, month, day);
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
window.formatBlogDate  = formatBlogDate;
"@

[System.IO.File]::WriteAllText($DATA_JS, $blogDataJS, [System.Text.Encoding]::UTF8)
Write-Host "✅  js/blog-data.js actualizado"

# ─── 2. js/blog-engine.js ─────────────────────────────────────────────────────
$articleEntries = ($mdFiles | ForEach-Object {
    $t = $_.title    -replace '\\', '\\\\'  -replace '"', '\"'
    $s = $_.slug     -replace '\\', '\\\\'  -replace '"', '\"'
    $d = $_.date     -replace '\\', '\\\\'  -replace '"', '\"'
    $c = $_.category -replace '\\', '\\\\'  -replace '"', '\"'
    $u = $_.summary  -replace '\\', '\\\\'  -replace '"', '\"'
    $b = Escape-TemplateLiteral $_.body
    $key = $_.slug -replace '\\', '\\\\'  -replace '"', '\"'
@"
  "$key": {
    title: "$t",
    slug: "$s",
    date: "$d",
    category: "$c",
    summary: "$u",
    body: ``$b``
  }
"@
}) -join ",`n`n"

$blogEngineJS = @"
/**
 * Asesoría CT - Motor de Artículos y Renderizador Markdown
 * ⚠️  ARCHIVO GENERADO AUTOMÁTICAMENTE por scripts/build-blog.ps1
 *     No editar a mano. Ejecutar: scripts/build-blog.ps1
 */

window.BLOG_ARTICLES_DATA = {
$articleEntries
};

/**
 * Función ligera para parsear Markdown a HTML
 */
function parseMarkdownToHTML(markdownText) {
  if (!markdownText) return '';

  let html = markdownText;

  // Normalizar saltos de línea
  html = html.replace(/\r\n/g, '\n');

  // Separadores horizontales
  html = html.replace(/^(?:---|\*\*\*|___)\s*`$`/gm, '<hr>');

  // Encabezados
  html = html.replace(/^#### (.*?)`$`/gm, '<h4>`$`1</h4>');
  html = html.replace(/^### (.*?)`$`/gm,  '<h3>`$`1</h3>');
  html = html.replace(/^## (.*?)`$`/gm,   '<h2>`$`1</h2>');
  html = html.replace(/^# (.*?)`$`/gm,    '<h1>`$`1</h1>');

  // Negrita e itálica
  html = html.replace(/\*\*\*(.*?)\*\*\*/g, '<strong><em>`$`1</em></strong>');
  html = html.replace(/\*\*(.*?)\*\*/g,     '<strong>`$`1</strong>');
  html = html.replace(/\*(.*?)\*/g,         '<em>`$`1</em>');

  // Código en línea
  html = html.replace(/``([^``]+)``/g, '<code>`$`1</code>');

  // Enlaces
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="`$`2" target="_blank" rel="noopener noreferrer">`$`1</a>');

  // Listas ordenadas y desordenadas
  html = html.replace(/^\s*\d+\.\s+(.*?)`$`/gm, '<li class="blog-ol-item">`$`1</li>');
  html = html.replace(/^\s*[-*]\s+(.*?)`$`/gm,  '<li class="blog-ul-item">`$`1</li>');

  html = html.replace(/((?:<li class="blog-ol-item">.*?<\/li>\s*)+)/g, '<ol>`$`1</ol>');
  html = html.replace(/((?:<li class="blog-ul-item">.*?<\/li>\s*)+)/g, '<ul>`$`1</ul>');

  html = html.replace(/ class="blog-ol-item"/g, '').replace(/ class="blog-ul-item"/g, '');

  // Párrafos
  const blocks = html.split(/\n{2,}/);
  html = blocks.map(block => {
    block = block.trim();
    if (!block) return '';
    if (/^<(?:h[1-6]|ul|ol|li|hr|div|blockquote|p)/i.test(block)) {
      return block;
    }
    return ``<p>`${block.replace(/\n/g, '<br>')}</p>``;
  }).filter(Boolean).join('\n\n');

  return html;
}

window.parseMarkdownToHTML = parseMarkdownToHTML;
"@

# Fix the template literal placeholders (we used `$` to avoid PS interpolation, now restore)
$blogEngineJS = $blogEngineJS -replace '`\$`', '$'

[System.IO.File]::WriteAllText($ENGINE_JS, $blogEngineJS, [System.Text.Encoding]::UTF8)
Write-Host "✅  js/blog-engine.js actualizado"

# ─── 3. content/blog-index.json ───────────────────────────────────────────────
$indexArr = $mdFiles | ForEach-Object {
    [PSCustomObject]@{
        title    = $_.title
        slug     = $_.slug
        date     = $_.date
        category = $_.category
        summary  = $_.summary
        file     = $_.file
    }
}
$indexJson = $indexArr | ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText($INDEX_JSON, $indexJson, [System.Text.Encoding]::UTF8)
Write-Host "✅  content/blog-index.json actualizado"

# ─── 4. sitemap.xml ───────────────────────────────────────────────────────────
$blogUrls = ($mdFiles | ForEach-Object {
@"
  <url>
    <loc>$BASE_URL/blog/$($_.slug)</loc>
    <lastmod>$($_.date)</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
"@
}) -join "`n"

$sitemapXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <!-- Paginas Principales -->
  <url>
    <loc>$BASE_URL/</loc>
    <lastmod>$TODAY</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>$BASE_URL/servicios.html</loc>
    <lastmod>$TODAY</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>$BASE_URL/quienes-somos.html</loc>
    <lastmod>$TODAY</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>$BASE_URL/contacto.html</loc>
    <lastmod>$TODAY</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>$BASE_URL/blog.html</loc>
    <lastmod>$TODAY</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.9</priority>
  </url>

  <!-- Articulos del Blog -->
$blogUrls

  <!-- Paginas Legales -->
  <url>
    <loc>$BASE_URL/terminos-y-condiciones.html</loc>
    <lastmod>2026-11-14</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
  <url>
    <loc>$BASE_URL/politica-de-privacidad.html</loc>
    <lastmod>2026-11-14</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
  <url>
    <loc>$BASE_URL/aviso-legal.html</loc>
    <lastmod>2026-11-14</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
</urlset>
"@

[System.IO.File]::WriteAllText($SITEMAP, $sitemapXml, [System.Text.Encoding]::UTF8)
Write-Host "✅  sitemap.xml actualizado"
Write-Host ""
Write-Host "🎉 Build completo: $($mdFiles.Count) artículos procesados."
