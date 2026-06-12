param(
    [string]$PlayStationIP = "",
    [int]$HttpPort = 8765,
    [int]$LocalUdpPort = 33740,
    [int]$RemoteUdpPort = 33739,
    [ValidateSet("A","B","~","C")]
    [string]$PacketVersion = "A",
    [switch]$Demo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not ("GT7Bridge.Salsa20" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Text;

namespace GT7Bridge
{
    public static class Salsa20
    {
        private static uint RotateLeft(uint value, int shift)
        {
            return (value << shift) | (value >> (32 - shift));
        }

        private static uint ToUInt32(byte[] input, int offset)
        {
            return (uint)(
                input[offset]
                | (input[offset + 1] << 8)
                | (input[offset + 2] << 16)
                | (input[offset + 3] << 24)
            );
        }

        private static void WriteUInt32(uint value, byte[] output, int offset)
        {
            output[offset] = (byte)value;
            output[offset + 1] = (byte)(value >> 8);
            output[offset + 2] = (byte)(value >> 16);
            output[offset + 3] = (byte)(value >> 24);
        }

        public static byte[] Process(byte[] key, byte[] iv, byte[] data)
        {
            if (key == null || key.Length != 32)
            {
                throw new ArgumentException("Key must be exactly 32 bytes.");
            }

            if (iv == null || iv.Length != 8)
            {
                throw new ArgumentException("IV must be exactly 8 bytes.");
            }

            byte[] sigma = Encoding.ASCII.GetBytes("expand 32-byte k");
            uint[] state = new uint[16];
            state[0] = ToUInt32(sigma, 0);
            state[1] = ToUInt32(key, 0);
            state[2] = ToUInt32(key, 4);
            state[3] = ToUInt32(key, 8);
            state[4] = ToUInt32(key, 12);
            state[5] = ToUInt32(sigma, 4);
            state[6] = ToUInt32(iv, 0);
            state[7] = ToUInt32(iv, 4);
            state[8] = 0;
            state[9] = 0;
            state[10] = ToUInt32(sigma, 8);
            state[11] = ToUInt32(key, 16);
            state[12] = ToUInt32(key, 20);
            state[13] = ToUInt32(key, 24);
            state[14] = ToUInt32(key, 28);
            state[15] = ToUInt32(sigma, 12);

            byte[] output = new byte[data.Length];
            byte[] block = new byte[64];
            int offset = 0;

            while (offset < data.Length)
            {
                uint[] x = (uint[])state.Clone();

                unchecked
                {
                    for (int i = 0; i < 10; i++)
                    {
                        x[4] ^= RotateLeft(x[0] + x[12], 7);
                        x[8] ^= RotateLeft(x[4] + x[0], 9);
                        x[12] ^= RotateLeft(x[8] + x[4], 13);
                        x[0] ^= RotateLeft(x[12] + x[8], 18);

                        x[9] ^= RotateLeft(x[5] + x[1], 7);
                        x[13] ^= RotateLeft(x[9] + x[5], 9);
                        x[1] ^= RotateLeft(x[13] + x[9], 13);
                        x[5] ^= RotateLeft(x[1] + x[13], 18);

                        x[14] ^= RotateLeft(x[10] + x[6], 7);
                        x[2] ^= RotateLeft(x[14] + x[10], 9);
                        x[6] ^= RotateLeft(x[2] + x[14], 13);
                        x[10] ^= RotateLeft(x[6] + x[2], 18);

                        x[3] ^= RotateLeft(x[15] + x[11], 7);
                        x[7] ^= RotateLeft(x[3] + x[15], 9);
                        x[11] ^= RotateLeft(x[7] + x[3], 13);
                        x[15] ^= RotateLeft(x[11] + x[7], 18);

                        x[1] ^= RotateLeft(x[0] + x[3], 7);
                        x[2] ^= RotateLeft(x[1] + x[0], 9);
                        x[3] ^= RotateLeft(x[2] + x[1], 13);
                        x[0] ^= RotateLeft(x[3] + x[2], 18);

                        x[6] ^= RotateLeft(x[5] + x[4], 7);
                        x[7] ^= RotateLeft(x[6] + x[5], 9);
                        x[4] ^= RotateLeft(x[7] + x[6], 13);
                        x[5] ^= RotateLeft(x[4] + x[7], 18);

                        x[11] ^= RotateLeft(x[10] + x[9], 7);
                        x[8] ^= RotateLeft(x[11] + x[10], 9);
                        x[9] ^= RotateLeft(x[8] + x[11], 13);
                        x[10] ^= RotateLeft(x[9] + x[8], 18);

                        x[12] ^= RotateLeft(x[15] + x[14], 7);
                        x[13] ^= RotateLeft(x[12] + x[15], 9);
                        x[14] ^= RotateLeft(x[13] + x[12], 13);
                        x[15] ^= RotateLeft(x[14] + x[13], 18);
                    }

                    for (int i = 0; i < 16; i++)
                    {
                        x[i] += state[i];
                        WriteUInt32(x[i], block, i * 4);
                    }
                }

                int blockLength = Math.Min(64, data.Length - offset);
                for (int i = 0; i < blockLength; i++)
                {
                    output[offset + i] = (byte)(data[offset + i] ^ block[i]);
                }

                offset += blockLength;

                unchecked
                {
                    state[8]++;
                    if (state[8] == 0)
                    {
                        state[9]++;
                    }
                }
            }

            return output;
        }
    }
}
"@
}

function Get-GT7KeyBytes {
    $source = [System.Text.Encoding]::ASCII.GetBytes("Simulator Interface Packet GT7 ver 0.0")
    $buffer = New-Object byte[] 32
    [Array]::Copy($source, $buffer, [Math]::Min(32, $source.Length))
    return $buffer
}

function Get-DecryptorXorValue {
    param([string]$Version)

    switch ($Version) {
        "A" { return 0xDEADBEAF }
        "B" { return 0xDEADBEEF }
        "~" { return 0x55FABB4F }
        "C" { return 0xDEADBEEF }
        default { return 0xDEADBEAF }
    }
}

function Get-JsonBytes {
    param([object]$Value)
    return [System.Text.Encoding]::UTF8.GetBytes(($Value | ConvertTo-Json -Depth 8 -Compress))
}

function Write-JsonResponse {
    param(
        [System.Net.HttpListenerContext]$Context,
        [object]$Body,
        [int]$StatusCode = 200
    )

    $response = $Context.Response
    $response.StatusCode = $StatusCode
    $response.ContentType = "application/json; charset=utf-8"
    $response.Headers["Access-Control-Allow-Origin"] = "*"
    $response.Headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    $response.Headers["Access-Control-Allow-Headers"] = "Content-Type"
    $response.Headers["Cache-Control"] = "no-store"

    $bytes = Get-JsonBytes $Body
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
    $response.OutputStream.Close()
}

function Write-EmptyResponse {
    param(
        [System.Net.HttpListenerContext]$Context,
        [int]$StatusCode = 204
    )

    $response = $Context.Response
    $response.StatusCode = $StatusCode
    $response.Headers["Access-Control-Allow-Origin"] = "*"
    $response.Headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    $response.Headers["Access-Control-Allow-Headers"] = "Content-Type"
    $response.OutputStream.Close()
}

function Read-FloatLE {
    param([byte[]]$Buffer, [int]$Offset)
    return [BitConverter]::ToSingle($Buffer, $Offset)
}

function Read-UInt32LE {
    param([byte[]]$Buffer, [int]$Offset)
    return [BitConverter]::ToUInt32($Buffer, $Offset)
}

function Read-Int32LE {
    param([byte[]]$Buffer, [int]$Offset)
    return [BitConverter]::ToInt32($Buffer, $Offset)
}

function Read-UInt16LE {
    param([byte[]]$Buffer, [int]$Offset)
    return [BitConverter]::ToUInt16($Buffer, $Offset)
}

function Read-Int16LE {
    param([byte[]]$Buffer, [int]$Offset)
    return [BitConverter]::ToInt16($Buffer, $Offset)
}

function Decode-GT7Packet {
    param(
        [byte[]]$Bytes,
        [string]$Version,
        [byte[]]$KeyBytes
    )

    if (-not $Bytes -or $Bytes.Length -lt 0x94) {
        return $null
    }

    $iv1 = [BitConverter]::ToInt32($Bytes, 0x40)
    $iv2 = $iv1 -bxor (Get-DecryptorXorValue -Version $Version)
    $nonce = New-Object byte[] 8
    [BitConverter]::GetBytes([uint32]$iv2).CopyTo($nonce, 0)
    [BitConverter]::GetBytes([uint32]$iv1).CopyTo($nonce, 4)

    $decoded = [GT7Bridge.Salsa20]::Process($KeyBytes, $nonce, $Bytes)
    $magic = Read-UInt32LE -Buffer $decoded -Offset 0x0
    if ($magic -ne 0x47375330) {
        return $null
    }

    $speedMs = [Math]::Max(0, (Read-FloatLE -Buffer $decoded -Offset 0x4C))
    $rpm = [Math]::Max(0, (Read-FloatLE -Buffer $decoded -Offset 0x3C))
    $fuelLevel = [Math]::Max(0, (Read-FloatLE -Buffer $decoded -Offset 0x44))
    $fuelCapacity = [Math]::Max(0, (Read-FloatLE -Buffer $decoded -Offset 0x48))
    $throttleRaw = [int]$decoded[0x91]
    $brakeRaw = [int]$decoded[0x92]
    $gearByte = [int]$decoded[0x90]
    $currentGear = $gearByte -band 0x0F
    $suggestedGear = ($gearByte -shr 4) -band 0x0F
    $flags = Read-Int16LE -Buffer $decoded -Offset 0x8E

    $fuelPct = if ($fuelCapacity -gt 0) {
        [Math]::Round(($fuelLevel / $fuelCapacity) * 100, 1)
    } else {
        0
    }

    return [ordered]@{
        connected = $true
        source = "gt7"
        packetVersion = $Version
        packetSize = $Bytes.Length
        packetId = [int](Read-UInt32LE -Buffer $decoded -Offset 0x70)
        speedKph = [Math]::Round($speedMs * 3.6, 1)
        rpm = [Math]::Round($rpm, 0)
        revLightMin = [int](Read-UInt16LE -Buffer $decoded -Offset 0x88)
        revLightMax = [int](Read-UInt16LE -Buffer $decoded -Offset 0x8A)
        brake = [Math]::Round(($brakeRaw / 255.0) * 100, 1)
        throttle = [Math]::Round(($throttleRaw / 255.0) * 100, 1)
        gear = if ($currentGear -gt 0) { $currentGear } else { "N" }
        gearNumber = $currentGear
        suggestedGear = $suggestedGear
        fuelPct = $fuelPct
        fuelLevel = [Math]::Round($fuelLevel, 2)
        fuelCapacity = [Math]::Round($fuelCapacity, 2)
        lap = [int](Read-UInt16LE -Buffer $decoded -Offset 0x74)
        totalLaps = [int](Read-UInt16LE -Buffer $decoded -Offset 0x76)
        bestLapMs = [int](Read-Int32LE -Buffer $decoded -Offset 0x78)
        lastLapMs = [int](Read-Int32LE -Buffer $decoded -Offset 0x7C)
        flags = $flags
        carOnTrack = [bool]($flags -band 1)
        paused = [bool]($flags -band 2)
        loading = [bool]($flags -band 4)
        inGear = [bool]($flags -band 8)
        updatedAt = (Get-Date).ToString("o")
    }
}

function New-BridgeState {
    param(
        [string]$Source = "waiting",
        [string]$Message = "Bridge starting"
    )

    return [ordered]@{
        connected = $false
        source = $Source
        packetVersion = $PacketVersion
        packetSize = 0
        packetId = 0
        speedKph = 0
        rpm = 0
        revLightMin = 0
        revLightMax = 0
        brake = 0
        throttle = 0
        gear = "N"
        gearNumber = 0
        suggestedGear = 0
        fuelPct = 0
        fuelLevel = 0
        fuelCapacity = 0
        lap = 0
        totalLaps = 0
        bestLapMs = -1
        lastLapMs = -1
        flags = 0
        carOnTrack = $false
        paused = $false
        loading = $false
        updatedAt = (Get-Date).ToString("o")
        lastPacketAgeMs = $null
        bridgeMessage = $Message
        playStationIP = $PlayStationIP
        httpPort = $HttpPort
        localUdpPort = $LocalUdpPort
        remoteUdpPort = $RemoteUdpPort
        demoMode = [bool]$Demo
    }
}

function Update-DemoTelemetry {
    param([hashtable]$State)

    $time = [double]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) / 1000.0
    $speed = 155 + ([Math]::Sin($time * 0.7) * 52) + ([Math]::Sin($time * 0.13) * 14)
    $rpm = 5200 + ([Math]::Sin($time * 1.2) * 2100)
    $brake = [Math]::Max(0, ([Math]::Sin($time * 0.55 + 1.2) * 55))
    $throttle = [Math]::Max(0, 100 - $brake + ([Math]::Sin($time * 1.7) * 10))
    $gearNumber = [Math]::Max(1, [Math]::Min(7, [int]([Math]::Floor($speed / 42))))

    $State.connected = $true
    $State.source = "demo"
    $State.packetId = [int]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() % 1000000)
    $State.speedKph = [Math]::Round([Math]::Max(0, $speed), 1)
    $State.rpm = [Math]::Round([Math]::Max(1000, $rpm), 0)
    $State.revLightMin = 7200
    $State.revLightMax = 8100
    $State.brake = [Math]::Round([Math]::Min(100, $brake), 1)
    $State.throttle = [Math]::Round([Math]::Min(100, [Math]::Max(0, $throttle)), 1)
    $State.gear = $gearNumber
    $State.gearNumber = $gearNumber
    $State.suggestedGear = if ($State.rpm -gt 7400) { [Math]::Min(7, $gearNumber + 1) } else { $gearNumber }
    $State.fuelCapacity = 100
    $State.fuelLevel = [Math]::Max(14, 100 - (($time * 0.9) % 75))
    $State.fuelPct = [Math]::Round(($State.fuelLevel / $State.fuelCapacity) * 100, 1)
    $State.lap = [int](($time / 95) % 7) + 1
    $State.totalLaps = 10
    $State.bestLapMs = 118540
    $State.lastLapMs = 120130
    $State.flags = 9
    $State.carOnTrack = $true
    $State.paused = $false
    $State.loading = $false
    $State.updatedAt = (Get-Date).ToString("o")
    $State.lastPacketAgeMs = 0
    $State.bridgeMessage = "Demo stream active"
}

$initialSource = if ($Demo) { "demo" } else { "waiting" }
$initialMessage = if ($Demo) { "Demo bridge ready" } else { "Waiting for GT7 telemetry" }
$sharedState = @{}
(New-BridgeState -Source $initialSource -Message $initialMessage).GetEnumerator() | ForEach-Object {
    $sharedState[$_.Key] = $_.Value
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$HttpPort/")
$udpClient = $null
$requestTask = $null
$lastHeartbeat = [DateTime]::MinValue
$lastPacketAt = $null
$keyBytes = Get-GT7KeyBytes

try {
    $listener.Start()
    Write-Host "GT7 local bridge listening on http://localhost:$HttpPort/"

    if (-not $Demo) {
        if ([string]::IsNullOrWhiteSpace($PlayStationIP)) {
            throw "Provide -PlayStationIP when not using -Demo."
        }

        $udpClient = [System.Net.Sockets.UdpClient]::new($LocalUdpPort)
        $udpClient.Client.ReceiveTimeout = 10
        Write-Host "UDP listener ready on port $LocalUdpPort for PlayStation $PlayStationIP"
    } else {
        Write-Host "Demo mode enabled. No PlayStation connection is required."
    }

    while ($listener.IsListening) {
        if ($requestTask -eq $null) {
            $requestTask = $listener.GetContextAsync()
        }

        if ($requestTask.IsCompleted) {
            $context = $requestTask.GetAwaiter().GetResult()
            $requestTask = $null

            try {
                switch ($context.Request.HttpMethod) {
                    "OPTIONS" {
                        Write-EmptyResponse -Context $context
                    }
                    "GET" {
                        switch ($context.Request.Url.AbsolutePath.TrimEnd("/")) {
                            "" { Write-JsonResponse -Context $context -Body $sharedState }
                            "/status" { Write-JsonResponse -Context $context -Body $sharedState }
                            "/telemetry" { Write-JsonResponse -Context $context -Body $sharedState }
                            default {
                                Write-JsonResponse -Context $context -Body ([ordered]@{
                                    error = "Not found"
                                    path = $context.Request.Url.AbsolutePath
                                }) -StatusCode 404
                            }
                        }
                    }
                    default {
                        Write-JsonResponse -Context $context -Body ([ordered]@{
                            error = "Method not allowed"
                        }) -StatusCode 405
                    }
                }
            } catch {
                Write-JsonResponse -Context $context -Body ([ordered]@{
                    error = $_.Exception.Message
                }) -StatusCode 500
            }
        }

        if ($Demo) {
            Update-DemoTelemetry -State $sharedState
        } else {
            $now = Get-Date
            if (($now - $lastHeartbeat).TotalSeconds -ge 12) {
                $heartbeatBytes = [System.Text.Encoding]::ASCII.GetBytes($PacketVersion)
                [void]$udpClient.Send($heartbeatBytes, $heartbeatBytes.Length, $PlayStationIP, $RemoteUdpPort)
                $lastHeartbeat = $now
            }

            while ($udpClient.Available -gt 0) {
                $remoteEndPoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
                $packetBytes = $udpClient.Receive([ref]$remoteEndPoint)
                $decodedPacket = Decode-GT7Packet -Bytes $packetBytes -Version $PacketVersion -KeyBytes $keyBytes
                if ($decodedPacket) {
                    foreach ($entry in $decodedPacket.GetEnumerator()) {
                        $sharedState[$entry.Key] = $entry.Value
                    }
                    $sharedState.bridgeMessage = "Live GT7 telemetry connected"
                    $sharedState.lastPacketAgeMs = 0
                    $lastPacketAt = Get-Date
                }
            }

            if ($lastPacketAt) {
                $ageMs = [int]((Get-Date) - $lastPacketAt).TotalMilliseconds
                $sharedState.lastPacketAgeMs = $ageMs
                if ($ageMs -gt 2500) {
                    $sharedState.connected = $false
                    $sharedState.source = "waiting"
                    $sharedState.bridgeMessage = "No recent GT7 packets. Keep the console and PC on the same network and enable data output in GT7."
                }
            }
        }

        Start-Sleep -Milliseconds 30
    }
}
finally {
    if ($udpClient) {
        $udpClient.Close()
    }
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
