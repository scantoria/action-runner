# F-2 A-E: synthetic identities/listeners, actual isolated Docker kill/restart.
$ErrorActionPreference = 'Stop'
$recoverySuffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
$recoveryContainers = [Collections.Generic.List[string]]::new()
$recoveryVolumes = [Collections.Generic.List[string]]::new()
$recoveryImage = 'thisbyte/actions-runner:2.328.0'
$recoveryWorkspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
function Assert-RecoveryDocker {
    if ($LASTEXITCODE -ne 0) { throw "Recovery Docker command exited $LASTEXITCODE" }
}
function Read-RecoveryVolume($Case, [string]$Code, [string[]]$Extra = @()) {
    docker run --rm --network none --entrypoint python3 --mount "type=volume,source=$($Case.Volume),target=/runner-state,readonly" $recoveryImage -c $Code @Extra
    Assert-RecoveryDocker
}
function New-RecoveryContainer($Case, [string]$Name, [int]$Migrate, [int]$Interrupt) {
    docker create --name $Name --network none --init --entrypoint bash --mount "type=volume,source=$($Case.Volume),target=/runner-state" --mount "type=bind,source=$recoveryWorkspace,target=/project,readonly" --env GITHUB_OWNER=scantoria --env GITHUB_REPOSITORY=thisbyte-website --env RUNNER_NAME=thisbyte-hp-runner --env "WP03_FIXTURE_MIGRATE=$Migrate" --env WP03_FIXTURE_MIGRATE_ONCE=1 --env "WP03_FIXTURE_INTERRUPT_RECOVERY=$Interrupt" $recoveryImage /project/tests/container-listener.sh | Out-Null
    Assert-RecoveryDocker
    $recoveryContainers.Add($Name)
}
function New-RecoveryCase([string]$Label, [int]$Migrate = 0, [int]$Interrupt = 0) {
    $volume = "wp03-f2-$Label-state-$recoverySuffix"
    $name = "wp03-f2-$Label-$recoverySuffix"
    docker volume create $volume | Out-Null
    Assert-RecoveryDocker
    $recoveryVolumes.Add($volume)
    docker run --rm --network none --entrypoint bash --mount "type=volume,source=$volume,target=/runner-state" --mount "type=bind,source=$recoveryWorkspace,target=/project,readonly" $recoveryImage /project/tests/lifecycle.sh seed | Out-Null
    Assert-RecoveryDocker
    $case = [pscustomobject]@{ Name = $name; Volume = $volume; Label = $Label; Base = $null }
    $case.Base = Read-RecoveryVolume $case 'import hashlib,pathlib; p=pathlib.Path("/runner-state"); print(" ".join(hashlib.sha256((p/f).read_bytes()).hexdigest() for f in [".runner",".credentials",".credentials_rsaparams",".env",".path"]))'
    New-RecoveryContainer $case $name $Migrate $Interrupt
    return $case
}
function Start-RecoveryReady($Case, [int]$StartNumber) {
    docker start $Case.Name | Out-Null
    Assert-RecoveryDocker
    $ready = $false
    for ($attempt = 0; $attempt -lt 150; $attempt++) {
        $value = docker exec $Case.Name cat /tmp/wp03-ready 2>$null
        if ($LASTEXITCODE -eq 0 -and "$value".Trim() -eq "$StartNumber") { $ready = $true; break }
        $info = (docker inspect $Case.Name | ConvertFrom-Json)[0]
        if (-not $info.State.Running) { break }
        Start-Sleep -Milliseconds 100
    }
    if (-not $ready) { docker logs $Case.Name; throw "Recovery $($Case.Label) did not reach listener start $StartNumber" }
    docker exec $Case.Name test ! -e /tmp/wp03-config-called
    Assert-RecoveryDocker
}
function Kill-RecoveryCase($Case) {
    docker kill --signal SIGKILL $Case.Name | Out-Null
    Assert-RecoveryDocker
    docker wait $Case.Name | Out-Null
    Assert-RecoveryDocker
    $info = (docker inspect $Case.Name | ConvertFrom-Json)[0]
    if ($info.State.Running -or $info.State.ExitCode -ne 137) { throw 'Expected actual Docker SIGKILL exit 137' }
    Read-RecoveryVolume $Case 'import pathlib; assert (pathlib.Path("/runner-state")/".listener-active").is_file()' | Out-Null
}
function Assert-RecoveryBase($Case) {
    $after = Read-RecoveryVolume $Case 'import hashlib,pathlib; p=pathlib.Path("/runner-state"); print(" ".join(hashlib.sha256((p/f).read_bytes()).hexdigest() for f in [".runner",".credentials",".credentials_rsaparams",".env",".path"]))'
    if ($after -cne $Case.Base) { throw 'Recovery changed the baseline identity' }
}
function Stop-RecoveryClean($Case) {
    docker stop --timeout 10 $Case.Name | Out-Null
    Assert-RecoveryDocker
    $info = (docker inspect $Case.Name | ConvertFrom-Json)[0]
    if ($info.State.ExitCode -ne 0) { docker logs $Case.Name; throw 'Recovery graceful stop failed' }
    Read-RecoveryVolume $Case 'import pathlib; p=pathlib.Path("/runner-state"); assert not (p/".listener-active").exists() and not (p/".listener-state-error").exists() and not list(p.glob(".pending*"))' | Out-Null
    Assert-RecoveryBase $Case
}
function Assert-RecoveryRefusal($Case, [int]$ExpectedStarts = 1) {
    docker start $Case.Name | Out-Null
    Assert-RecoveryDocker
    docker wait $Case.Name | Out-Null
    Assert-RecoveryDocker
    $info = (docker inspect $Case.Name | ConvertFrom-Json)[0]
    $logs = (docker logs $Case.Name 2>&1) -join "`n"
    if ($info.State.ExitCode -ne 1 -or ([regex]::Matches($logs, 'Synthetic listener started using retained state')).Count -ne $ExpectedStarts -or $logs -match 'FAIL: ordinary migrated restart') {
        Write-Output $logs
        throw 'Expected fail-closed refusal before new listener/configuration/removal'
    }
    Read-RecoveryVolume $Case 'import pathlib; p=pathlib.Path("/runner-state"); assert (p/".listener-active").exists(); assert not (p/".bootstrap-in-progress").exists() and not (p/".decommission-in-progress").exists()' | Out-Null
    Assert-RecoveryBase $Case
}
try {
    # Test A: same container, no runtime mutation, prove zero regular promotions.
    $caseA = New-RecoveryCase 'a'
    Start-RecoveryReady $caseA 1
    Kill-RecoveryCase $caseA
    Start-RecoveryReady $caseA 2
    $logs = (docker logs $caseA.Name) -join "`n"
    if ($logs -notmatch 'promoted_regular_files=0' -or $logs -notmatch 'Proven same-container interrupted finalization completed') { throw 'Unchanged-state finalization was not demonstrated' }
    Stop-RecoveryClean $caseA
    Write-Output 'PASS: F-2 Test A: actual SIGKILL=137, same-container unchanged identity recovered with zero promotions, token-free start, no config/remove/replace.'

    # Test B: pending migration exists only in retained layer before recovery.
    $caseB = New-RecoveryCase 'b' 1
    Start-RecoveryReady $caseB 1
    Read-RecoveryVolume $caseB 'import pathlib; p=pathlib.Path("/runner-state"); assert not (p/".credentials_migrated").exists() and not (p/".runner_migrated").exists()' | Out-Null
    Kill-RecoveryCase $caseB
    Start-RecoveryReady $caseB 2
    Read-RecoveryVolume $caseB 'import json,os,pathlib,stat; p=pathlib.Path("/runner-state"); assert all(stat.S_IMODE((p/f).stat().st_mode)==0o600 and (p/f).stat().st_uid==os.getuid() and json.loads((p/f).read_text())["fixtureGeneration"]==1 for f in [".credentials_migrated",".runner_migrated"])' | Out-Null
    Stop-RecoveryClean $caseB
    Write-Output 'PASS: F-2 Test B: SIGKILL migration recovered from original layer and persisted at generation 1, mode 0600, runner ownership, without bootstrap/removal.'

    # Test C: fresh layer cannot complete a prior container's active transaction.
    $caseC = New-RecoveryCase 'c' 1
    Start-RecoveryReady $caseC 1
    Kill-RecoveryCase $caseC
    $markerBefore = Read-RecoveryVolume $caseC 'import hashlib,pathlib; print(hashlib.sha256(pathlib.Path("/runner-state/.listener-active").read_bytes()).hexdigest())'
    $replacement = $caseC.Name + '-new'
    New-RecoveryContainer $caseC $replacement 0 0
    $recreated = [pscustomobject]@{ Name=$replacement; Volume=$caseC.Volume; Label='c-new'; Base=$caseC.Base }
    Assert-RecoveryRefusal $recreated 0
    $markerAfter = Read-RecoveryVolume $caseC 'import hashlib,pathlib; print(hashlib.sha256(pathlib.Path("/runner-state/.listener-active").read_bytes()).hexdigest())'
    if ($markerBefore -cne $markerAfter) { throw 'Recreation changed the rejected marker' }
    Write-Output 'PASS: F-2 Test C: recreation with retained volume/missing original local evidence refuses; no listener/config/remove/replace; marker and base identity intact.'

    # Test D: mutate only synthetic continuity evidence, then kill and restart.
    foreach ($kind in @('missing','malformed','mismatch','container','duplicate','mode','symlink','legacy')) {
        $caseD = New-RecoveryCase ('d-' + $kind)
        Start-RecoveryReady $caseD 1
        docker exec $caseD.Name python3 -c 'import json,pathlib,sys; l=pathlib.Path("/actions-runner/.listener-session"); m=pathlib.Path("/runner-state/.listener-active"); kind=sys.argv[1]; v=json.loads(l.read_text());
if kind=="missing": l.unlink()
elif kind=="malformed": l.write_text("{invalid")
elif kind=="mismatch": v["nonce"]="0"*64; l.write_text(json.dumps(v))
elif kind=="container": v["container"]="unrelated-container"; l.write_text(json.dumps(v)); m.write_text(json.dumps(v))
elif kind=="duplicate": m.write_text("{\"version\":1,\"version\":1}")
elif kind=="mode": l.chmod(0o644)
elif kind=="symlink": l.unlink(); l.symlink_to(m)
elif kind=="legacy": m.write_text("")' $kind
        Assert-RecoveryDocker
        Kill-RecoveryCase $caseD
        $markerBefore = Read-RecoveryVolume $caseD 'import hashlib,pathlib; print(hashlib.sha256(pathlib.Path("/runner-state/.listener-active").read_bytes()).hexdigest())'
        Assert-RecoveryRefusal $caseD
        $markerAfter = Read-RecoveryVolume $caseD 'import hashlib,pathlib; print(hashlib.sha256(pathlib.Path("/runner-state/.listener-active").read_bytes()).hexdigest())'
        if ($markerBefore -cne $markerAfter) { throw 'Bad continuity was silently changed' }
        Write-Output "PASS: F-2 Test D/${kind}: continuity refused before new listener/config/remove; durable evidence and base identity preserved."
    }

    # Test E: interrupt recovery after a complete staged copy, then either resume
    # the exact matching copy or refuse an intentionally corrupted synthetic one.
    foreach ($corrupt in @($false, $true)) {
        $label = if ($corrupt) { 'e-partial' } else { 'e-complete' }
        $caseE = New-RecoveryCase $label 1 1
        Start-RecoveryReady $caseE 1
        Kill-RecoveryCase $caseE
        docker start $caseE.Name | Out-Null
        Assert-RecoveryDocker
        $checkpoint = $false
        for ($attempt = 0; $attempt -lt 150; $attempt++) {
            docker exec $caseE.Name test -f /tmp/wp03-recovery-checkpoint 2>$null
            if ($LASTEXITCODE -eq 0) { $checkpoint=$true; break }
            Start-Sleep -Milliseconds 100
        }
        if (-not $checkpoint) { docker logs $caseE.Name; throw 'Interrupted-recovery checkpoint not reached' }
        Read-RecoveryVolume $caseE 'import pathlib; p=pathlib.Path("/runner-state"); assert (p/".listener-active").exists() and (p/".pending.credentials_migrated").is_file() and not (p/".credentials_migrated").exists()' | Out-Null
        if ($corrupt) {
            docker exec $caseE.Name python3 -c 'import pathlib; pathlib.Path("/runner-state/.pending.credentials_migrated").write_text("{}")'
            Assert-RecoveryDocker
        }
        Kill-RecoveryCase $caseE
        if ($corrupt) {
            Assert-RecoveryRefusal $caseE
            Read-RecoveryVolume $caseE 'import pathlib; p=pathlib.Path("/runner-state"); assert (p/".pending.credentials_migrated").read_text()=="{}" and not (p/".credentials_migrated").exists() and (p/".listener-state-error").is_file()' | Out-Null
            Write-Output 'PASS: F-2 Test E/partial: interrupted recovery with mismatched staged data fails closed; no premature marker clearance or invalid promotion/deletion.'
        } else {
            Start-RecoveryReady $caseE 3
            Read-RecoveryVolume $caseE 'import json,pathlib; p=pathlib.Path("/runner-state"); assert all(json.loads((p/f).read_text())["fixtureGeneration"]==1 for f in [".runner_migrated",".credentials_migrated"]) and not list(p.glob(".pending*"))' | Out-Null
            Stop-RecoveryClean $caseE
            Write-Output 'PASS: F-2 Test E/complete: SIGKILL during recovery kept marker; next same-container startup resumed complete matching staging and persisted valid migration before listener.'
        }
    }
} finally {
    foreach ($name in $recoveryContainers) {
        docker container inspect $name 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { docker rm -f $name | Out-Null }
    }
    foreach ($volume in $recoveryVolumes) {
        docker volume rm $volume | Out-Null
        Assert-RecoveryDocker
    }
    Write-Output 'Cleanup: only F-2 fixtures created by this run removed; no real identity or remote operation.'
}
