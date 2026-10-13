# Local synthetic-container validation only. No real registration/removal tokens.
$ErrorActionPreference = 'Stop'
$wp03Suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
$wp03Volume = 'wp03-validation-state-' + $wp03Suffix
$wp03Containers = @()
$wp03VolumeCreated = $false
$wp03Image = 'thisbyte/actions-runner:2.328.0'
$wp03Workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
function Assert-DockerExit {
    if ($LASTEXITCODE -ne 0) { throw "Docker command exited $LASTEXITCODE" }
}
try {
    docker volume create $wp03Volume | Out-Null
    Assert-DockerExit
    $wp03VolumeCreated = $true
    docker run --rm --network none --entrypoint bash --mount "type=volume,source=$wp03Volume,target=/runner-state" --mount "type=bind,source=$wp03Workspace,target=/project,readonly" $wp03Image /project/tests/lifecycle.sh
    Assert-DockerExit
    $wp03Before = docker run --rm --network none --entrypoint bash --mount "type=volume,source=$wp03Volume,target=/runner-state" $wp03Image -c 'sha256sum /runner-state/.runner /runner-state/.credentials /runner-state/.credentials_rsaparams /runner-state/.env /runner-state/.path'
    Assert-DockerExit
    $wp03Generation = 0
    foreach ($wp03Signal in @('TERM', 'INT')) {
        $wp03Name = 'wp03-listener-' + $wp03Suffix + '-' + $wp03Signal.ToLower()
        docker create --name $wp03Name --network none --init --entrypoint bash --mount "type=volume,source=$wp03Volume,target=/runner-state" --mount "type=bind,source=$wp03Workspace,target=/project,readonly" --env GITHUB_OWNER=scantoria --env GITHUB_REPOSITORY=thisbyte-website --env RUNNER_NAME=thisbyte-hp-runner $wp03Image /project/tests/container-listener.sh | Out-Null
        Assert-DockerExit
        $wp03Containers += $wp03Name
        $wp03Inspect = (docker inspect $wp03Name | ConvertFrom-Json)[0]
        Assert-DockerExit
        $wp03Exposed = @($wp03Inspect.Config.ExposedPorts.PSObject.Properties).Where({ $null -ne $_ }).Count
        $wp03Bindings = @($wp03Inspect.HostConfig.PortBindings.PSObject.Properties).Where({ $null -ne $_ }).Count
        if ($wp03Inspect.Config.User -ne 'runner' -or $wp03Inspect.HostConfig.Privileged -or $wp03Exposed -ne 0 -or $wp03Bindings -ne 0 -or ($wp03Inspect.Mounts | Where-Object { $_.Destination -eq '/var/run/docker.sock' })) {
            throw 'Container security check failed'
        }
        Write-Output 'PASS: Runtime inspect: User=runner, privileged=false, ports=none, Docker socket=absent, network=none.'
        foreach ($wp03Cycle in @('fresh-container', 'same-container-restart')) {
            docker start $wp03Name | Out-Null
            Assert-DockerExit
            $wp03Ready = $false
            for ($wp03Attempt = 0; $wp03Attempt -lt 100; $wp03Attempt++) {
                docker exec $wp03Name test -f /tmp/wp03-ready 2>$null
                if ($LASTEXITCODE -eq 0) { $wp03Ready = $true; break }
                Start-Sleep -Milliseconds 100
            }
            if (-not $wp03Ready) { docker logs $wp03Name; throw 'Listener not ready' }
            docker exec $wp03Name test ! -e /tmp/wp03-config-called
            Assert-DockerExit
            if ($wp03Signal -eq 'TERM') {
                docker stop --timeout 10 $wp03Name | Out-Null
            } else {
                docker kill --signal SIGINT $wp03Name | Out-Null
                Assert-DockerExit
                docker wait $wp03Name | Out-Null
            }
            Assert-DockerExit
            docker logs $wp03Name
            Assert-DockerExit
            $wp03Exit = (docker inspect $wp03Name | ConvertFrom-Json)[0].State.ExitCode
            if ($wp03Exit -ne 0) { throw "Listener exit $wp03Exit" }
            $wp03After = docker run --rm --network none --entrypoint bash --mount "type=volume,source=$wp03Volume,target=/runner-state" $wp03Image -c 'sha256sum /runner-state/.runner /runner-state/.credentials /runner-state/.credentials_rsaparams /runner-state/.env /runner-state/.path'
            Assert-DockerExit
            if (($wp03Before -join "`n") -cne ($wp03After -join "`n")) { throw 'Persistent state changed' }
            $wp03Generation++
            docker run --rm --network none --entrypoint python3 --mount "type=volume,source=$wp03Volume,target=/runner-state" $wp03Image -c 'import json,os,pathlib,stat,sys; root=pathlib.Path("/runner-state"); files=[root/".runner_migrated",root/".credentials_migrated"]; assert all(p.is_file() and not p.is_symlink() and stat.S_IMODE(p.stat().st_mode)==0o600 and p.stat().st_uid==os.getuid() and json.loads(p.read_text())["fixtureGeneration"]==int(sys.argv[1]) for p in files); assert not (root/".listener-active").exists(); print("PASS: F-1 migrated state is persisted at mode 0600, runner-owned, expected generation, with no incomplete finalization marker.")' $wp03Generation
            Assert-DockerExit
            Write-Output "PASS: Docker $wp03Signal/$wp03Cycle exit=0; migrated generation=$wp03Generation; base identity hashes unchanged; no bootstrap/removal."
            }
        docker rm $wp03Name | Out-Null
        Assert-DockerExit
    }
} finally {
    foreach ($wp03CreatedName in $wp03Containers) {
        docker container inspect $wp03CreatedName 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { docker rm -f $wp03CreatedName | Out-Null }
    }
    if ($wp03VolumeCreated) {
        docker volume rm $wp03Volume | Out-Null
        Assert-DockerExit
    }
    Write-Output 'Cleanup: only this run''s isolated fixture containers and volume removed.'
}
& (Join-Path $PSScriptRoot 'validate-recovery.ps1')
