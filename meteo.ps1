param(
    [string]$city,
	[switch]$h = $false
)

Write-Output "Proszę czekać..."

$cache_dir = "$env:USERPROFILE\AppData\Local\Temp\cache\meteo"

New-Item -ItemType Directory -Path $cache_dir -Force | Out-Null
$url1 = "https://danepubliczne.imgw.pl/api/data/synop"

$data1 = Invoke-RestMethod -Uri $url1

$stacja_lista = @()
$stacja_lista_pol = @()



for ($i = 0; $i -lt $data1.Length; $i++) {
	$nazwaStacji = $data1[$i].stacja
	$nazwaStacji = $nazwaStacji.Replace("ą", "a").Replace("ć", "c").Replace("ę", "e").Replace("ł", "l").Replace("ń", "n").Replace("ó", "o").Replace("ś", "s").Replace("ż", "z").Replace("ź", "z")
	$nazwaStacji = $nazwaStacji.Replace("Ć", "C").Replace("Ł", "L").Replace("Ś", "S").Replace("Ż", "Z").Replace("Ź", "Z")
	$stacja_lista += $nazwaStacji
}

for ($i = 0; $i -lt $data1.Length; $i++) {
	$nazwaStacji = $data1[$i].stacja
	$stacja_lista_pol += $nazwaStacji
}

	if ($city) {
       $miasto = $city
    }
	elseif ($h) {
		Write-Host "Użycie: ./meteo.ps1 -city NazwaMiasta"
		Write-Host "Jeśli nazwa miasta jest dwuczłonowa, zapisz ją w formie Nazwa_Miasta"
		exit 1
	} 
	else {
		Write-Host "Skorzystaj z -h."
		exit 1
	}
$miasto_pl = $miasto

$miasto = $miasto.Replace("ą", "a").Replace("ć", "c").Replace("ę", "e").Replace("ł", "l").Replace("ń", "n").Replace("ó", "o").Replace("ś", "s").Replace("ż", "z").Replace("ź", "z")
$miasto = $miasto.Replace("Ć", "C").Replace("Ł", "L").Replace("Ś", "S").Replace("Ż", "Z").Replace("Ź", "Z")

$url2 = "https://nominatim.openstreetmap.org/search?q=$miasto&format=json"

$data2 = Invoke-RestMethod -Uri $url2

$szerokosc = $data2[0].lat

$dlugosc = $data2[0].lon

$st_min_url="https://nominatim.openstreetmap.org/search?q=$($stacja_lista[0])&format=json"

$st_min_data = Invoke-RestMethod -Uri $st_min_url

$min_lat = $st_min_data[0].lat

$min_lon = $st_min_data[0].lon

function dist{
    param (
        [double]$arg1,
        [double]$arg2,
		[double]$arg3,
		[double]$arg4
		)
	
	$result = ($arg1 - $arg3)*($arg1 - $arg3) + ($arg2 - $arg4)*($arg2 - $arg4)
	
	$result = $result -replace ',', '.'
	
	return $result	
}

$min_num = dist -arg1 $min_lat -arg2 $min_lon -arg3 $szerokosc -arg4 $dlugosc

$min_stacja=$($stacja_lista[0])

$min_index = 0

if ((Get-ChildItem -Path $cache_dir).Count -gt 0) {
    foreach ($index in 0..($stacja_lista.Length - 1)) {
        $stacja = $stacja_lista[$index]
        $path = Join-Path $cache_dir "$stacja.json"
        $jsonData = Get-Content $path | ConvertFrom-Json
        $lat = $jsonData.lat
        $lon = $jsonData.lon
        $num = dist -arg1 $lat -arg2 $lon -arg3 $szerokosc -arg4 $dlugosc
        if ($num -lt $min_num) {
            $min_num = $num
            $min_stacja = $stacja
            $min_index = $index
        }
    }
} else {
    foreach ($index in 0..($stacja_lista.Length - 1)) {
        $stacja = $stacja_lista[$index]
        $st_min_url = "https://nominatim.openstreetmap.org/search?q=${stacja}&format=json"
        $st_min_data = Invoke-RestMethod -Uri $st_min_url -Method Get
		Start-Sleep -Seconds 1
		Write-Output "Proszę czekać..."
        $lat = $st_min_data[0].lat
        $lon = $st_min_data[0].lon
        $num = dist -arg1 $lat -arg2 $lon -arg3 $szerokosc -arg4 $dlugosc
        $cache_file = Join-Path $cache_dir "$stacja.json"
        $jsonData = @{
            stacja = $stacja
            lat = $lat
            lon = $lon
        } | ConvertTo-Json

        $jsonData | Set-Content -Path $cache_file -Force

        if ($num -lt $min_num) {
            $min_num = $num
            $min_stacja = $stacja
            $min_index = $index
        }
    }
}

$miasto_pol = $($stacja_lista_pol[$min_index])

Write-Output "Podane miasto: $miasto_pl"

$url = "https://danepubliczne.imgw.pl/api/data/synop"

$response = Invoke-RestMethod -Uri $url -Method Get

if ($?) 
{
    $miastoData = $response | Where-Object { $_.stacja -eq $miasto_pol }
    Write-Host "Dane pogodowe dla $miasto_pol :"
    $miastoData | ConvertTo-Json
}