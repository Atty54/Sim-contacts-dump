$portName = "COM6"
$exportDir = "C:\SIM_Archive\"

if (!(Test-Path $exportDir)) { New-Item -ItemType Directory -Path $exportDir | Out-Null }

try {
    $port = New-Object System.IO.Ports.SerialPort $portName, 9600, None, 8, One
    $port.Open()
    
    Write-Host "`n--- ИНИЦИАЛИЗАЦИЯ СКАНЕРА ---" -ForegroundColor Cyan

    # 1. Получаем IMSI
    $port.Write("AT+CIMI`r")
    Start-Sleep -m 500
    $imsiRaw = $port.ReadExisting()
    $imsi = ($imsiRaw -split "`r`n" | Where-Object { $_ -match '^\d{10,15}$' }).Trim()
    if (!$imsi) { $imsi = "UNKNOWN_" + (Get-Date -Format "HHmmss") }
    $filePath = Join-Path $exportDir "$imsi.txt"

    # 2. Читаем название оператора (EF_SPN) с улучшенной эвристикой
    $port.Write("AT+CRSM=176,28486,0,0,17`r")
    Start-Sleep -m 500
    $spnRaw = $port.ReadExisting()
    
    $operator = "Unknown"
    if ($spnRaw -match '\+CRSM:\s*\d+,\d+,"([0-9A-F]+)"') {
        $hex = $matches[1].Substring(2)
        $hex = $hex -replace '(FF)+$', ''
        
        if ($hex.Length -ge 2) {
            $bytes = for($j=0; $j -lt $hex.Length; $j+=2) { [Convert]::ToByte($hex.Substring($j, 2), 16) }
            if ($hex.Contains("00") -or $hex.StartsWith("8")) {
                $operator = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes).Trim().Replace("`0", "")
            } else {
                $operator = [System.Text.Encoding]::ASCII.GetString($bytes).Trim()
            }
        }
    }

    # 3. Настройка памяти и вывод статистики
    $port.Write("AT+CSCS=`"UCS2`"`r")
    Start-Sleep -m 300
    $port.Write("AT+CPBS=`"SM`"`r")
    Start-Sleep -s 1
    $port.Write("AT+CPBS?`r")
    Start-Sleep -s 1
    $memInfo = $port.ReadExisting()
    
    # Вывод информации о памяти в консоль
    Write-Host "ИНФО О ПАМЯТИ:" -ForegroundColor Yellow
    Write-Host $memInfo -ForegroundColor Gray

    $maxIndex = 250
    $usedCount = 0
    if ($memInfo -match '\+CPBS:\s*"SM",(\d+),(\d+)') {
        $usedCount = $matches[1]
        $maxIndex = $matches[2]
    }

    Write-Host "----------------------------------------" -ForegroundColor White
    Write-Host "IMSI: $imsi" -ForegroundColor Green
    Write-Host "Operator: $operator" -ForegroundColor Green
    Write-Host "Занято ячеек: $usedCount из $maxIndex" -ForegroundColor Green
    Write-Host "----------------------------------------" -ForegroundColor White

    Write-Host "Ожидание индексации 15 сек..." -ForegroundColor Gray
    Start-Sleep -s 15

    # 4. Сбор контактов блоками
    $rawResult = ""
    for ($start = 1; $start -le $maxIndex; $start += 20) {
        $end = [math]::Min($start + 19, $maxIndex)
        Write-Host "Читаю блок $start-$end..." -ForegroundColor Gray
        $port.Write("AT+CPBR=$start,$end`r")
        Start-Sleep -s 2
        $rawResult += $port.ReadExisting()
    }

    # 5. Формирование отчета
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $report = @(
        "========================================",
        "IMSI: $imsi",
        "Operator: $operator",
        "Timestamp: $timestamp",
        "Total Contacts Found: $usedCount",
        "========================================",
        ""
    )

    $finalContacts = @()
    $lines = $rawResult -split "`r`n"
    foreach ($line in $lines) {
        if ($line -match '\+CPBR:\s*\d+,"([^"]+)",\d+,"([0-9A-F]+)"') {
            $phone = $matches[1]
            $hexName = $matches[2]
            try {
                $bName = for($k=0; $k -lt $hexName.Length; $k+=2) { [Convert]::ToByte($hexName.Substring($k, 2), 16) }
                $decName = [System.Text.Encoding]::BigEndianUnicode.GetString($bName).Trim().Replace("`0", "")
                $finalContacts += "$decName : $phone"
            } catch {}
        }
    }

    # 6. Сохранение и финальный вывод
    $report += $finalContacts
    $report | Out-File -FilePath $filePath -Encoding UTF8
    
    Write-Host "`nУСПЕШНО ЗАВЕРШЕНО!" -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "Файл: $filePath" -ForegroundColor White
    Write-Host "Декодировано контактов: $($finalContacts.Count)" -ForegroundColor Cyan
}
catch {
    Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($port -and $port.IsOpen) { $port.Close() }
    Write-Host "Порт закрыт. Можно менять SIM.`n" -ForegroundColor Gray
}