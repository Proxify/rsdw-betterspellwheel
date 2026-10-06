param([ValidateSet('Guard','Suite')][string]$Mode='Suite',
      [string]$Installer='D:\rsdw-mods\dist\BetterSpellWheel-0.2.2-setup.exe',
      [string]$Manifest='D:\rsdw-mods\dist\BetterSpellWheel-0.2.2-setup.manifest.json')
$ErrorActionPreference='Stop'
$root=Join-Path 'D:\rsdw-mods\repl' ('bsw-installer-tests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$results=[System.Collections.Generic.List[string]]::new()
$hashes=Get-Content -Raw $Manifest | ConvertFrom-Json
function Assert($condition,[string]$message) { if (!$condition) { throw $message } }
function Put([string]$path,[string]$value) {
 New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
 [IO.File]::WriteAllText($path,$value,[Text.Encoding]::ASCII)
}
function Game([string]$name) {
 $dir=Join-Path $root $name
 Put (Join-Path $dir 'RSDragonwilds\Binaries\Win64\RSDragonwilds-Win64-Shipping.exe') 'TEST DIRECTORY ONLY'
 return $dir
}
function Win64([string]$dir) { return Join-Path $dir 'RSDragonwilds\Binaries\Win64' }
function Run([string]$dir,[string]$extra='',[int]$expect=0) {
 $args=@('/silent',('/dir="'+$dir+'"'));if($extra){$args+=$extra}
 $p=Start-Process -FilePath $Installer -ArgumentList $args -Wait -PassThru
 Assert ($p.ExitCode -eq $expect) ('Unexpected exit '+$p.ExitCode+' for '+$dir+' '+$extra)
}
function Installed([string]$mod,[bool]$skipConfig=$false) {
 foreach($p in $hashes.PSObject.Properties){
  if(!$p.Name.StartsWith('BetterSpellWheel/')){continue}
  $rel=$p.Name.Substring(17).Replace('/','\')
  if($skipConfig -and $rel -eq 'config.txt'){continue}
  $file=Join-Path $mod $rel
  Assert (Test-Path $file) ('Missing '+$rel)
  Assert ((Get-FileHash $file -Algorithm SHA256).Hash.ToLower() -eq $p.Value) ('Payload mismatch '+$rel)
 }
}
function Pass([string]$name) { $results.Add('PASS: '+$name);Write-Output ('PASS: '+$name) }
try {
 if($Mode -eq 'Guard') {
  Assert (@(Get-Process -Name 'RSDragonwilds-Win64-Shipping' -ErrorAction SilentlyContinue).Count -gt 0) 'Running-game test requires the already-authorized test client'
  $dir=Game 'running';Run $dir '' 1
  Assert (!(Test-Path (Join-Path (Win64 $dir) 'ue4ss'))) 'Running-game guard wrote files'
  Assert ((Get-Content -Raw (Join-Path $env:TEMP 'BetterSpellWheel-install.log')) -match 'game is still running') 'Wrong refusal reason'
  Pass 'running game refuses with no installation writes'
 } else {
  Assert (@(Get-Process -Name 'RSDragonwilds-Win64-Shipping' -ErrorAction SilentlyContinue).Count -eq 0) 'Close authorized test game before success cases'
  $dir=Game 'fresh install';$w=Win64 $dir;$m=Join-Path $w 'ue4ss\Mods\BetterSpellWheel'
  Run $dir;Installed $m
  foreach($name in @('UE4SS.dll','UE4SS-settings.ini','UE4SS-LICENSE.txt')) {
   Assert ((Get-FileHash (Join-Path $w ('ue4ss\'+$name))).Hash.ToLower() -eq $hashes.$name) ('Dependency mismatch '+$name)
  }
  Assert ((Get-FileHash (Join-Path $w 'dwmapi.dll')).Hash.ToLower() -eq $hashes.'dwmapi.dll') 'Loader mismatch'
  Pass 'fresh install: all 15 mod files and four dependency hashes match'
  Put (Join-Path $m 'config.txt') 'Enabled=false';Put (Join-Path $m 'data\keep.txt') 'user data'
  Put (Join-Path $m 'Scripts\main.lua') 'old mod version'
  Run $dir;Installed $m $true;Run $dir
  Assert ((Get-Content -Raw (Join-Path $m 'config.txt')) -eq 'Enabled=false') 'Config overwritten'
  Assert ((Get-Content -Raw (Join-Path $m 'data\keep.txt')) -eq 'user data') 'Data overwritten'
  Assert (@(Get-Content (Join-Path $w 'ue4ss\Mods\mods.txt') | Where-Object {$_ -match '^BetterSpellWheel\s*:\s*1'}).Count -eq 1) 'Duplicate enable lines'
  Pass 'upgrade and repeat install preserve custom config/data and enable once'
  Run $dir '/uninstall';Assert (!(Test-Path $m)) 'Mod remains'
  Assert (!(Test-Path (Join-Path $w 'ue4ss'))) 'Installer-owned unused UE4SS remains'
  Assert (!(Test-Path (Join-Path $w 'dwmapi.dll'))) 'Installer-owned loader remains'
  Pass 'uninstall removes this mod and installer-owned unused UE4SS'

  $dir=Game 'shared dependency';$w=Win64 $dir;Run $dir
  Put (Join-Path $w 'ue4ss\Mods\OtherMod\enabled.txt') 'keep'
  Put (Join-Path $w 'ue4ss\Mods\mods.txt') "OtherMod : 1`r`nBetterSpellWheel : 1`r`n"
  Run $dir '/uninstall'
  Assert (Test-Path (Join-Path $w 'ue4ss\UE4SS.dll')) 'Shared UE4SS removed'
  Assert (Test-Path (Join-Path $w 'dwmapi.dll')) 'Shared loader removed'
  Assert ((Get-Content -Raw (Join-Path $w 'ue4ss\Mods\OtherMod\enabled.txt')) -eq 'keep') 'Other mod removed'
  Pass 'uninstall retains bundled UE4SS when another mod needs it'

  foreach($legacy in @($false,$true)) {
   $dir=Game ('existing-'+$legacy);$w=Win64 $dir
   $ue=if($legacy){$w}else{Join-Path $w 'ue4ss'}
   $mods=Join-Path $ue 'Mods';$m=Join-Path $mods 'BetterSpellWheel'
   Put (Join-Path $ue 'UE4SS.dll') 'existing UE4SS';Put (Join-Path $ue 'UE4SS-settings.ini') 'existing settings'
   Put (Join-Path $w 'dwmapi.dll') 'existing loader'
   Put (Join-Path $mods 'OtherMod\enabled.txt') 'other mod'
   Put (Join-Path $mods 'mods.txt') "OtherMod : 1`r`nBetterSpellWheelExtra : 1`r`nBetterSpellWheel : 0`r`nBetterSpellWheel : 1`r`n; Built-in keybinds`r`nKeybinds : 1"
   Run $dir;Installed $m
   $text=Get-Content -Raw (Join-Path $mods 'mods.txt')
   Assert (($text -split '\r?\n' | Where-Object {$_ -match '^BetterSpellWheel\s*:\s*1'}).Count -eq 1) 'Duplicate normalized lines'
   Assert ($text.Contains('BetterSpellWheelExtra : 1') -and $text.IndexOf('BetterSpellWheel : 1') -lt $text.IndexOf('Keybinds : 1')) 'Other entry/keybind order changed'
   Run $dir '/uninstall'
   Assert ((Get-Content -Raw (Join-Path $ue 'UE4SS.dll')) -eq 'existing UE4SS') 'Existing UE4SS overwritten'
   Assert ((Get-Content -Raw (Join-Path $ue 'UE4SS-settings.ini')) -eq 'existing settings') 'Existing settings overwritten'
   Assert ((Get-Content -Raw (Join-Path $w 'dwmapi.dll')) -eq 'existing loader') 'Existing loader overwritten'
   Assert ((Get-Content -Raw (Join-Path $mods 'OtherMod\enabled.txt')) -eq 'other mod') 'Other mod removed'
   Pass ('existing UE4SS/other mods preserved, duplicate loader entries normalized; legacy='+$legacy)
  }
  $dir=Game 'collision';$w=Win64 $dir;Put (Join-Path $w 'dwmapi.dll') 'other loader';Run $dir '' 1
  Assert ((Get-Content -Raw (Join-Path $w 'dwmapi.dll')) -eq 'other loader') 'Conflicting loader overwritten'
  Assert (!(Test-Path (Join-Path $w 'ue4ss'))) 'Collision mutated target'
  Pass 'conflicting loader refused without modification'
  $dir=Join-Path $root 'invalid';New-Item -ItemType Directory $dir | Out-Null;Run $dir '' 1
  Assert (@(Get-ChildItem -Force $dir).Count -eq 0) 'Invalid target mutated'
  Pass 'invalid target refused without modification'
  $dir=Game 'old name';$w=Win64 $dir;Put (Join-Path $w 'ue4ss\Mods\SpellBranches\enabled.txt') 'old mod';Run $dir '' 1
  Assert (!(Test-Path (Join-Path $w 'ue4ss\Mods\BetterSpellWheel'))) 'Old-name collision installed duplicate'
  Pass 'old SpellBranches folder refused before writes'
  $dir=Game 'junction';$w=Win64 $dir;$outside=Join-Path $root 'linked source'
  Put (Join-Path $outside 'sentinel.txt') 'keep'
  New-Item -ItemType Directory -Force (Join-Path $w 'ue4ss\Mods') | Out-Null
  New-Item -ItemType Junction -Path (Join-Path $w 'ue4ss\Mods\BetterSpellWheel') -Target $outside | Out-Null
  Run $dir '' 1;Run $dir '/uninstall' 1
  Assert ((Get-Content -Raw (Join-Path $outside 'sentinel.txt')) -eq 'keep') 'Junction target changed'
  Assert (@(Get-ChildItem -Force $outside).Count -eq 1) 'Junction target gained files'
  Pass 'junction install/uninstall refused with linked source intact'
  $interactive=Game 'interactive'
  [IO.File]::WriteAllText('D:\rsdw-mods\repl\bsw-installer-interactive-path.txt',$interactive)
 }
} finally {
 $results | Set-Content (Join-Path $root 'results.txt')
 Write-Output ('Evidence: '+$root)
}
