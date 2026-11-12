$port = 8080
$baseDir = "C:\Users\hossa\.gemini\antigravity\scratch\3d-website"
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
$listener.Server.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)

try {
    $listener.Start()
    Write-Host "=========================================================="
    Write-Host " 3D Web Server Running on Port $port"
    Write-Host " Local (PC):        http://localhost:$port/"
    Write-Host " Network (Phone):   http://192.168.0.151:$port/"
    Write-Host " Developer Mode:     http://192.168.0.151:$port/?admin=mashrafi"
    Write-Host "=========================================================="
} catch {
    Write-Host "Port error: $_"
    exit 1
}

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".svg"  = "image/svg+xml"
    ".webp" = "image/webp"
    ".ico"  = "image/x-icon"
}

$buffer = New-Object byte[] 8192

while ($true) {
    try {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $stream.ReadTimeout = 3000
        $stream.WriteTimeout = 5000

        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        if ($bytesRead -le 0) {
            $client.Close()
            continue
        }

        $requestText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
        $firstLine = $requestText.Split([string[]]@("`r`n", "`n"), [System.StringSplitOptions]::None)[0]
        $tokens = $firstLine.Split(" ")
        
        $targetUrl = if ($tokens.Length -gt 1) { $tokens[1] } else { "/" }
        $cleanPath = $targetUrl.Split("?")[0].TrimStart('/')
        if ([string]::IsNullOrEmpty($cleanPath)) {
            $cleanPath = "index.html"
        }

        $cleanPath = [System.Uri]::UnescapeDataString($cleanPath).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $fullPath = Join-Path $baseDir $cleanPath

        if (Test-Path $fullPath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
            $contentType = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }
            $contentBytes = [System.IO.File]::ReadAllBytes($fullPath)

            $header = "HTTP/1.1 200 OK`r`n" +
                      "Content-Type: $contentType`r`n" +
                      "Content-Length: $($contentBytes.Length)`r`n" +
                      "Access-Control-Allow-Origin: *`r`n" +
                      "Cache-Control: no-cache`r`n" +
                      "Connection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($contentBytes, 0, $contentBytes.Length)
        } else {
            $errBody = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $cleanPath")
            $header = "HTTP/1.1 404 Not Found`r`n" +
                      "Content-Type: text/plain`r`n" +
                      "Content-Length: $($errBody.Length)`r`n" +
                      "Connection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($errBody, 0, $errBody.Length)
        }

        $stream.Flush()
        $client.Close()
    } catch {
        # ignore read errors
    }
}
