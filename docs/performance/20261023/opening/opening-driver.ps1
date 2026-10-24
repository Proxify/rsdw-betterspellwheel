<#
BSW opening-hitch input driver (session 115173b7). Windows PowerShell 5.1. Development test tool, NOT native-accepted:
native acceptance belongs to the Blade operator (712).
Sends a FIXED, BOUNDED number of real Q press/release cycles to one identified game process and logs every injection
with a QPC (Stopwatch) bracket. It sends no other keys, clicks or Lua, steals no focus and starts no watchers/recording.

  powershell.exe -WindowStyle Hidden -File opening-driver.ps1 -GamePid <pid> -ProcStartUtc <o-format UTC>
      -ExeSha256 <hex> -ExpectHost SUDOBLADE -Out C:\...\<label>.events.json [-Cycles 3]

Ready/go gate: all setup (Add-Type, self hash, exe hash, identity/focus checks) runs first. Then the driver writes
<Out>.ready and waits at most 30 s (100 ms sleeps, no watcher process) for <Out>.go. The operator starts the
PresentMon capture only after .ready exists and then creates .go. On go: the fixed 4000 ms lead, then for each cycle
(Tap mode only; Q down/up toggles the wheel on Main/PR6/PR7 as verified by 712):
  open  = one logical tap: Q down, HoldMs, Q up; OpenDwellMs
  close = one logical tap: Q down, HoldMs, Q up; ClosedGapMs
Each injection keeps its own QPC bracket. The event is the whole tap: [down.qpcBefore, up.qpcAfter].
'open'/'close' are INTENDED transitions, not proof that the UI opened. The operator proves the wheel is closed and in
the correct input mode before the run and proves the state after it. Events are buffered in memory and written once,
in finally.
Abort (status 'aborted', reason logged): not a 64-bit PowerShell (the INPUT struct is laid out for x64), Q already
held (GetAsyncKeyState high bit) before one of our key downs, wrong host, game identity mismatch, process gone, foreground window not owned
by the game PID before any keydown/keyup, SendInput result != 1, Stopwatch not high resolution. Q up is always sent in
finally if Q is down. The events JSON is written in finally.
#>
param(
  [Parameter(Mandatory=$true)][int]$GamePid,
  [Parameter(Mandatory=$true)][string]$ProcStartUtc,
  [Parameter(Mandatory=$true)][string]$ExeSha256,
  [Parameter(Mandatory=$true)][string]$ExpectHost,
  [Parameter(Mandatory=$true)][string]$Out,
  [ValidateRange(1,4)][int]$Cycles = 3,
  [ValidateRange(60,250)][int]$HoldMs = 120,
  [ValidateRange(1500,5000)][int]$OpenDwellMs = 2000,
  [ValidateRange(1500,5000)][int]$ClosedGapMs = 2500
)
$ErrorActionPreference = 'Stop'
# Never overwrite earlier evidence: refuse before anything (including the finally-block log) can write.
foreach ($f in $Out, "$Out.ready", "$Out.go") {
  if (Test-Path -LiteralPath $f) { Write-Output "REFUSED: $f already exists"; exit 2 }
}
$LeadMs = 4000            # fixed by the protocol
$GoTimeoutMs = 30000      # bounded wait for the operator's go file
$Mode = 'Tap'
$MaxPlannedMs = 30000     # whole driver timeline after setup must fit a 30 s capture
$ExeName = 'RSDragonwilds-Win64-Shipping'
$VkQ = 0x51
$log = [ordered]@{
  tool = 'bsw115-opening-driver'; version = 1; status = 'starting'; reason = $null
  host = $env:COMPUTERNAME; user = $env:USERNAME; pid = $GamePid; procStartUtc = $ProcStartUtc; exeSha256 = $ExeSha256
  mode = $Mode; cycles = $Cycles; leadMs = $LeadMs; holdMs = $HoldMs; openDwellMs = $OpenDwellMs; closedGapMs = $ClosedGapMs
  driverSha256 = $null; qpcFrequency = $null; qpcHighResolution = $null
  setupDoneQpc = $null; endQpc = $null; injections = @(); events = @()
}
$planned = $LeadMs + $Cycles * (2 * $HoldMs + $OpenDwellMs + $ClosedGapMs)
$log.plannedMs = $planned
$qDown = $false
$sw = [Diagnostics.Stopwatch]

function Write-Log { ConvertTo-Json -InputObject $log -Depth 6 | Set-Content -Encoding UTF8 -Path $Out }
function Abort($why) { $log.status = 'aborted'; $log.reason = $why; throw "ABORT: $why" }
function Check-Identity {
  $p = Get-Process -Id $GamePid -ErrorAction SilentlyContinue
  if (-not $p) { Abort "game process $GamePid gone" }
  if ($p.ProcessName -ne $ExeName) { Abort "pid $GamePid is $($p.ProcessName)" }
  if ($p.StartTime.ToUniversalTime().ToString('o') -ne $ProcStartUtc) { Abort "pid $GamePid start $($p.StartTime.ToUniversalTime().ToString('o')) != $ProcStartUtc" }
  $p
}
function Check-Focus($what) {
  $h = [BswOpen]::GetForegroundWindow()
  $fp = [uint32]0
  [void][BswOpen]::GetWindowThreadProcessId($h, [ref]$fp)
  if ($fp -ne [uint32]$GamePid) { Abort "foreground window pid $fp is not the game before $what" }
}
function Inject($ev, $up) {
  # Same SendInput convention as tools/cu.ps1 U.Key: vk + MapVirtualKey scancode, KEYEVENTF_SCANCODE(8) | KEYUP(2).
  [void](Check-Identity)
  Check-Focus "$($ev.kind) $(if ($up) { 'up' } else { 'down' })"
  # Never claim or release a Q that something else is holding: before OUR key down, Q must be up.
  if (-not $up -and ([BswOpen]::GetAsyncKeyState($VkQ) -band 0x8000)) { Abort "Q already held before $($ev.kind) down" }
  if ($up -and -not $script:qDown) { Abort "refusing key up for $($ev.kind): no key down of ours is pending" }
  $u0 = (Get-Date).ToUniversalTime().ToString('o')
  $q0 = $sw::GetTimestamp()
  $r = [BswOpen]::Key($VkQ, $up)
  $q1 = $sw::GetTimestamp()
  $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
  $rec = [ordered]@{ cycle = $ev.cycle; kind = $ev.kind; phase = $(if ($up) { 'up' } else { 'down' }); qpcBefore = $q0; qpcAfter = $q1; utcBefore = $u0; sendInput = $r; lastError = $err }
  $log.injections += $rec
  if (-not $up) { $script:qDown = $true }
  if ($r -ne 1) { Abort "SendInput returned $r (error $err) for $($ev.kind) $($rec.phase)" }
  if ($up) { $script:qDown = $false }
  $rec
}

try {
  if ($env:COMPUTERNAME -ne $ExpectHost) { Abort "host $env:COMPUTERNAME != $ExpectHost" }
  if ($planned -gt $MaxPlannedMs) { Abort "planned timeline $planned ms exceeds $MaxPlannedMs ms" }
  if (-not [Environment]::Is64BitProcess) { Abort 'not a 64-bit PowerShell process (INPUT size 40 assumes x64)' }
  if (-not $sw::IsHighResolution) { Abort 'Stopwatch is not high resolution (QPC unavailable)' }
  $log.qpcFrequency = $sw::Frequency; $log.qpcHighResolution = $true
  $log.driverSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash
  Add-Type @'
using System; using System.Runtime.InteropServices;
public static class BswOpen {
  [StructLayout(LayoutKind.Sequential)] public struct KI { public ushort vk; public ushort sc; public uint fl; public uint t; public IntPtr ex; }
  [StructLayout(LayoutKind.Explicit, Size=40)] public struct IN { [FieldOffset(0)] public uint type; [FieldOffset(8)] public KI ki; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, IN[] i, int sz);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint c, uint t);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vk);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public static uint Key(byte vk, bool up) {
    ushort sc = (ushort)MapVirtualKey(vk, 0); uint fl = 8u | (up ? 2u : 0u);
    var a = new IN[1]; a[0].type = 1; a[0].ki.vk = vk; a[0].ki.sc = sc; a[0].ki.fl = fl;
    return SendInput(1, a, Marshal.SizeOf(typeof(IN)));
  }
}
'@
  $p = Check-Identity
  $exe = (Get-FileHash -Algorithm SHA256 -LiteralPath $p.Path).Hash
  if ($exe -ne $ExeSha256.ToUpper()) { Abort "exe hash $exe != $ExeSha256" }
  Check-Focus 'start'
  $log.setupDoneQpc = $sw::GetTimestamp()
  Set-Content -LiteralPath "$Out.ready" -Value "ready qpc=$($log.setupDoneQpc) freq=$($log.qpcFrequency)"
  $log.status = 'ready'
  $waitStart = $sw::GetTimestamp()
  while (-not (Test-Path -LiteralPath "$Out.go")) {
    if (($sw::GetTimestamp() - $waitStart) * 1000 / $sw::Frequency -gt $GoTimeoutMs) { Abort "no go file within $GoTimeoutMs ms" }
    Start-Sleep -Milliseconds 100
  }
  $log.goQpc = $sw::GetTimestamp()
  [void](Check-Identity); Check-Focus 'go'
  $log.status = 'running'
  Start-Sleep -Milliseconds $LeadMs
  for ($c = 1; $c -le $Cycles; $c++) {
    foreach ($kind in 'open', 'close') {
      $ev = [ordered]@{ cycle = $c; kind = $kind; intended = "intended $kind" }
      $d = Inject $ev $false; Start-Sleep -Milliseconds $HoldMs; $u = Inject $ev $true
      # One logical tap event: down bracket start .. up bracket end; the injections keep their own brackets.
      $ev.downQpcBefore = $d.qpcBefore; $ev.downQpcAfter = $d.qpcAfter; $ev.upQpcBefore = $u.qpcBefore; $ev.upQpcAfter = $u.qpcAfter
      $log.events += $ev
      Start-Sleep -Milliseconds $(if ($kind -eq 'open') { $OpenDwellMs } else { $ClosedGapMs })
    }
  }
  $log.status = 'complete'
} catch {
  if ($log.status -ne 'aborted') { $log.status = 'aborted'; $log.reason = "error: $($_.Exception.Message)" }
} finally {
  if ($qDown) {
    # Release Q whatever happened; logged as a safety release, never as an event.
    $q0 = $sw::GetTimestamp()
    $r = try { [BswOpen]::Key($VkQ, $true) } catch { -1 }
    $log.safetyRelease = [ordered]@{ qpcBefore = $q0; qpcAfter = $sw::GetTimestamp(); sendInput = $r }
  }
  $log.endQpc = $sw::GetTimestamp()
  Write-Log
}
if ($log.status -ne 'complete') { exit 1 }
