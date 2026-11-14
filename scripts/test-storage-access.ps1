param(
    [string]$Config = 'config/connection.json',
    [string]$EmailA = $env:TICKETGUARD_TEST_EMAIL_A,
    [string]$PasswordA = $env:TICKETGUARD_TEST_PASSWORD_A,
    [string]$EmailB = $env:TICKETGUARD_TEST_EMAIL_B,
    [string]$PasswordB = $env:TICKETGUARD_TEST_PASSWORD_B,
    [string]$Photo = 'docs/fixtures/ticket-ensayo.jpg',
    [switch]$OwnerOnly
)

$ErrorActionPreference = 'Stop'
if (-not ($EmailA -and $PasswordA) -or (-not $OwnerOnly -and (-not ($EmailB -and $PasswordB) -or $EmailA -eq $EmailB))) {
    throw 'Configura las cuatro variables de dos cuentas de ensayo distintas y confirmadas.'
}
$connection = Get-Content -Raw $Config | ConvertFrom-Json
$baseUrl = $connection.SUPABASE_URL
$key = $connection.SUPABASE_PUBLISHABLE_KEY
if (-not $baseUrl -or -not $key) { throw 'Faltan URL y clave publicable.' }
$anonymous = @{ apikey = $key }

function Get-TestHeaders([string]$Email, [string]$Password) {
    $payload = @{email=$Email; password=$Password} | ConvertTo-Json -Compress
    $session = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/token?grant_type=password" -Headers $anonymous -ContentType 'application/json' -Body $payload -TimeoutSec 25
    return @{ user = $session.user.id; headers = @{
        apikey = $key
        Authorization = "Bearer $($session.access_token)"
        Prefer = 'return=representation'
    }}
}

function Invoke-Check([string]$Label, [string]$Method, [string]$Path, [hashtable]$Headers,
    [int[]]$Expected, [object]$Payload = $null, [string]$ContentType = 'application/json') {
    $options = @{
        Method=$Method
        Uri="$baseUrl$Path"
        Headers=$Headers
        ContentType=$ContentType
        TimeoutSec=25
        SkipHttpErrorCheck=$true
    }
    if ($null -ne $Payload) {
        if ($ContentType -eq 'application/json') { $options.Body = ConvertTo-Json -InputObject $Payload -Compress }
        else { $options.Body = $Payload }
    }
    $reply = Invoke-WebRequest @options
    if ([int]$reply.StatusCode -notin $Expected) {
        $detail = if ($reply.Content -is [string]) { $reply.Content.Substring(0, [Math]::Min(350, $reply.Content.Length)) } else { "respuesta binaria ($($reply.RawContentLength) bytes)" }
        throw "$Label -> HTTP $($reply.StatusCode). $detail"
    }
    Write-Host "$Label -> HTTP $($reply.StatusCode)"
    return $reply
}

$A = Get-TestHeaders $EmailA $PasswordA
if (-not $OwnerOnly) { $B = Get-TestHeaders $EmailB $PasswordB }
$id = [guid]::NewGuid().ToString()
$objectName = "$($A.user)/$id.jpg"
$objectPath = "/storage/v1/object/receipt-images/$objectName"
$privatePath = "/storage/v1/object/authenticated/receipt-images/$objectName"
$rowPath = "/rest/v1/tickets?id=eq.$id"
$jpeg = [IO.File]::ReadAllBytes((Resolve-Path $Photo).Path)
$inserted = $false

try {
    $null = Invoke-Check 'Acceso anónimo a la tabla denegado' GET $rowPath $anonymous @(401,403)
    $row = @{
        id=$id; user_id=$A.user; product='Ticket de ensayo'; store='Tienda de ensayo'
        purchased_on=(Get-Date).ToString('yyyy-MM-dd'); amount_cents=129900
    }
    if (-not $OwnerOnly) { $null = Invoke-Check 'B no puede crear a nombre de A' POST '/rest/v1/tickets' $B.headers @(403) $row }
    $invalid = $row.Clone()
    $invalid.amount_cents = -1
    $null = Invoke-Check 'Importe negativo rechazado' POST '/rest/v1/tickets' $A.headers @(400) $invalid
    $null = Invoke-Check 'A crea fila provisional' POST '/rest/v1/tickets' $A.headers @(201) $row
    $inserted = $true
    $null = Invoke-Check 'Se impide finalizar sin foto' PATCH $rowPath $A.headers @(400) @{status='ready'}
    if (-not $OwnerOnly) { $null = Invoke-Check 'B no puede escribir en la ruta de A' POST $objectPath $B.headers @(400,403) $jpeg 'image/jpeg' }
    $null = Invoke-Check 'Tipo de archivo rechazado' POST $objectPath $A.headers @(400,415) ([byte[]]@(1,2,3)) 'text/plain'
    $null = Invoke-Check 'Tamaño superior a 5 MiB rechazado' POST $objectPath $A.headers @(400,413) ([byte[]]::new(5242881)) 'image/jpeg'
    $A.headers['Cache-Control'] = 'max-age=0'
    $null = Invoke-Check 'A sube foto privada' POST $objectPath $A.headers @(200,201) $jpeg 'image/jpeg'
    $null = Invoke-Check 'A finaliza' PATCH $rowPath $A.headers @(200) @{status='ready'}
    $visible = Invoke-Check 'A consulta el ticket finalizado' GET $rowPath $A.headers @(200)
    $own = @($visible.Content | ConvertFrom-Json)
    if ($own.Count -ne 1 -or $own[0].status -ne 'ready') { throw 'Falta el ticket listo.' }
    $download = Invoke-Check 'A descarga la foto' GET $privatePath $A.headers @(200)
    if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$download.Content)) -ne
        [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($jpeg))) { throw 'La foto recuperada difiere.' }
    if (-not $OwnerOnly) {
        foreach ($method in @('GET','PATCH','DELETE')) {
            $payload = if ($method -eq 'PATCH') { @{product='Alterado'} } else { $null }
            $hidden = Invoke-Check "B intenta $method por UUID" $method $rowPath $B.headers @(200) $payload
            if ($hidden.Content.Trim() -ne '[]') { throw "B accedió al ticket de A mediante $method." }
        }
        $null = Invoke-Check 'B no accede a la foto' GET $privatePath $B.headers @(400,403,404)
    }
    $null = Invoke-Check 'Sin URL pública' GET "/storage/v1/object/public/receipt-images/$objectName" $anonymous @(400,403,404)
    $null = Invoke-Check 'A marca eliminación' PATCH $rowPath $A.headers @(200) @{status='deleting'}
    $null = Invoke-Check 'Se impide borrar fila mientras conserva foto' DELETE $rowPath $A.headers @(400)
    $remove = Invoke-Check 'A elimina el archivo' DELETE '/storage/v1/object/receipt-images' $A.headers @(200) @{prefixes=@($objectName)}
    if ($remove.Content.Trim() -eq '[]') { throw 'Storage no confirmó el borrado del archivo.' }
    $null = Invoke-Check 'A elimina la fila' DELETE $rowPath $A.headers @(200)
    $inserted = $false
    $gone = Invoke-Check 'Registro eliminado' GET $rowPath $A.headers @(200)
    if ($gone.Content.Trim() -ne '[]') { throw 'La fila todavía existe.' }
    $freshPath = '{0}?cacheNonce={1}' -f $privatePath, [guid]::NewGuid()
    $null = Invoke-Check 'Archivo eliminado, consulta sin caché CDN' GET $freshPath $A.headers @(400,403,404)
    if ($OwnerOnly) { Write-Host 'Validación de propietario y acceso público completada.' }
    else { Write-Host 'Validación en dos cuentas completada.' }
} finally {
    if ($inserted) {
        try {
            $null = Invoke-Check 'Limpieza de fila de ensayo' PATCH $rowPath $A.headers @(200) @{status='deleting'}
            $null = Invoke-Check 'Limpieza de archivo de ensayo' DELETE '/storage/v1/object/receipt-images' $A.headers @(200) @{prefixes=@($objectName)}
            $null = Invoke-Check 'Limpieza final de fila de ensayo' DELETE $rowPath $A.headers @(200)
        } catch {
            Write-Warning "Verifica el borrado del registro de ensayo $id."
        }
    }
}
