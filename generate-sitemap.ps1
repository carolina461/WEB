# Script de generacion automatica de sitemap.xml para Asesoria CT
$baseUrl = "https://asesoriact.com"
$today = (Get-Date).ToString("yyyy-MM-dd")

$xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <!-- Paginas Principales -->
  <url>
    <loc>$baseUrl/</loc>
    <lastmod>$today</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>$baseUrl/servicios.html</loc>
    <lastmod>$today</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>$baseUrl/quienes-somos.html</loc>
    <lastmod>$today</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>$baseUrl/contacto.html</loc>
    <lastmod>$today</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>$baseUrl/blog.html</loc>
    <lastmod>$today</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.9</priority>
  </url>

  <!-- Articulos del Blog -->
"@

# Leer coleccion de articulos de Pages CMS (content/blog/*.md)
$blogFiles = Get-ChildItem -Path "content/blog/*.md" -ErrorAction SilentlyContinue
foreach ($file in $blogFiles) {
    $content = Get-Content $file.FullName -Raw
    $slug = ""
    $date = $today
    if ($content -match '(?m)^slug:\s*["'']?([^"''\r\n]+)["'']?') {
        $slug = $matches[1].Trim()
    } else {
        $slug = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    }
    if ($content -match '(?m)^date:\s*["'']?([^"''\r\n]+)["'']?') {
        $date = $matches[1].Trim()
    }
    $xml += @"

  <url>
    <loc>$baseUrl/blog/$slug</loc>
    <lastmod>$date</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
"@
}

$xml += @"

  <!-- Paginas Legales -->
  <url>
    <loc>$baseUrl/terminos-y-condiciones.html</loc>
    <lastmod>2026-11-14</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
  <url>
    <loc>$baseUrl/politica-de-privacidad.html</loc>
    <lastmod>2026-11-14</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
  <url>
    <loc>$baseUrl/aviso-legal.html</loc>
    <lastmod>2026-11-14</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
</urlset>
"@

$xml | Set-Content "sitemap.xml" -Encoding UTF8
Write-Output "sitemap.xml generado exitosamente con $($blogFiles.Count) articulos de blog."
