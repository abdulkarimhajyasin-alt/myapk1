param()

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result([string]$Name, [bool]$Passed) {
  $results.Add([pscustomobject]@{ Scenario = $Name; Result = $(if ($Passed) { 'PASS' } else { 'FAIL' }) })
}

function New-TechnicalPassword([string]$MemberId, [string]$MemberPassword) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes("MaskanAuthV2:${MemberId}:$($MemberPassword.Trim())")
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

$local = npx supabase status -o json | ConvertFrom-Json
$apiUrl = $local.API_URL
$anonKey = $local.ANON_KEY
$anonHeaders = @{ apikey = $anonKey; Authorization = "Bearer $anonKey" }

function Invoke-Auth([string]$Path, [hashtable]$Body) {
  Invoke-RestMethod -Method Post -Uri "$apiUrl/auth/v1/$Path" -Headers @{ apikey = $anonKey } `
    -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 8)
}

function Try-Auth([string]$Path, [hashtable]$Body) {
  try { return Invoke-Auth $Path $Body } catch { return $null }
}

function New-MemberAuth([string]$MemberId, [string]$MemberPassword) {
  Invoke-Auth 'signup' @{
    email = "maskan-$MemberId@auth.maskan.app"
    password = New-TechnicalPassword $MemberId $MemberPassword
  }
}

function Sign-InMember([string]$MemberId, [string]$MemberPassword) {
  Try-Auth 'token?grant_type=password' @{
    email = "maskan-$MemberId@auth.maskan.app"
    password = New-TechnicalPassword $MemberId $MemberPassword
  }
}

function Invoke-Edge([hashtable]$Body, [string]$AccessToken = $anonKey) {
  Invoke-RestMethod -Method Post -Uri "$apiUrl/functions/v1/maskan-password" `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $AccessToken" } `
    -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 8)
}

function Invoke-UserRpc([string]$Name, [hashtable]$Body, [string]$AccessToken) {
  Invoke-RestMethod -Method Post -Uri "$apiUrl/rest/v1/rpc/$Name" `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $AccessToken" } `
    -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 8)
}

function Db-Scalar([string]$Sql) {
  $value = docker exec supabase_db_myapkprojekt psql -U postgres -d postgres -X -qAt -c $Sql 2>$null
  if ($LASTEXITCODE -ne 0) { throw 'Local SQL assertion failed.' }
  $first = $value | Select-Object -First 1
  if ($null -eq $first) { return '' }
  return $first.Trim()
}

$ownerId = [guid]::NewGuid().ToString()
$networkId = [guid]::NewGuid().ToString()
$ownerPassword = 'OwnerFixture42!'
$networkPassword = 'NetworkFixture42!'
$ownerAuth = New-MemberAuth $ownerId $ownerPassword
$created = Invoke-Edge @{
  action = 'create_network'; networkId = $networkId; memberId = $ownerId
  networkName = "modern-$networkId"; memberName = 'Modern Owner'
  networkPassword = $networkPassword; memberPassword = $ownerPassword
  currencyCode = 'EUR'; currencySymbol = 'EUR'
} $ownerAuth.access_token
Add-Result 'new network request succeeds' ($created.ok -eq $true)
Add-Result 'new network is modern only' ((Db-Scalar "select count(*) from private.network_credentials where network_id='$networkId' and credential_version >= 2 and password_digest is not null and legacy_password_hash is null and legacy_password_salt is null") -eq '1')
Add-Result 'new owner is modern only' ((Db-Scalar "select count(*) from private.member_credentials where member_id='$ownerId' and credential_version >= 2 and password_digest is not null and legacy_password_hash is null and legacy_password_salt is null") -eq '1')

$modernWrong = Invoke-Edge @{
  action = 'verify_member'; networkName = "modern-$networkId"
  memberName = 'Modern Owner'; memberPassword = 'DefinitelyWrong42!'
}
$modernCorrect = Invoke-Edge @{
  action = 'verify_member'; networkName = "modern-$networkId"
  memberName = 'Modern Owner'; memberPassword = $ownerPassword
}
Add-Result 'modern wrong password rejected' ($modernWrong.ok -eq $false -and $modernWrong.code -eq 'invalid_credentials')
Add-Result 'modern correct password succeeds' ($modernCorrect.ok -eq $true)
Add-Result 'modern credential cannot downgrade' ((Db-Scalar "select count(*) from private.member_credentials where member_id='$ownerId' and credential_version >= 2 and legacy_password_hash is null") -eq '1')

$rateLimitFailuresAccepted = $true
1..5 | ForEach-Object {
  $badAttempt = Invoke-Edge @{
    action = 'verify_member'; networkName = "modern-$networkId"
    memberName = 'Modern Owner'; memberPassword = 'RateLimitWrong42!'
  }
  if ($badAttempt.ok -ne $false -or $badAttempt.code -ne 'invalid_credentials') {
    $rateLimitFailuresAccepted = $false
  }
}
Add-Result 'first five failed password attempts are handled normally' $rateLimitFailuresAccepted

$rateLimitedStatus = 0
$rateLimitedCode = ''
try {
  [void](Invoke-Edge @{
    action = 'verify_member'; networkName = "modern-$networkId"
    memberName = 'Modern Owner'; memberPassword = 'RateLimitWrong42!'
  })
} catch {
  $rateLimitedStatus = [int]$_.Exception.Response.StatusCode
  try { $rateLimitedCode = ($_.ErrorDetails.Message | ConvertFrom-Json).code } catch { }
}
Add-Result 'sixth failed password attempt returns HTTP 429' (
  $rateLimitedStatus -eq 429 -and $rateLimitedCode -eq 'rate_limited'
)
Add-Result 'rate-limit state stores no plaintext identifiers' (
  (Db-Scalar "select count(*) from private.password_rate_limits where key_hash ~ '^[0-9a-f]{64}$' and scope='member_verify' and failed_attempts=5") -eq '1'
)
[void](Db-Scalar "update private.password_rate_limits set expires_at=clock_timestamp()-interval '1 second'")
$afterExpiry = Invoke-Edge @{
  action = 'verify_member'; networkName = "modern-$networkId"
  memberName = 'Modern Owner'; memberPassword = $ownerPassword
}
Add-Result 'valid password works after rate-limit expiry' ($afterExpiry.ok -eq $true)
Add-Result 'successful verification clears its rate-limit state' (
  (Db-Scalar "select count(*) from private.password_rate_limits where scope='member_verify'") -eq '0'
)

$legacyNetworkId = [guid]::NewGuid().ToString()
$legacyMemberId = [guid]::NewGuid().ToString()
$legacyNetworkPassword = 'LegacyNetwork42!'
$legacyMemberPassword = 'LegacyMember42!'
$legacyNetworkName = "legacy-$legacyNetworkId"
$legacySql = @"
insert into public.networks(id,name,normalized_name,currency_code,currency_symbol)
values ('$legacyNetworkId','$legacyNetworkName','$legacyNetworkName','EUR','EUR');
insert into private.network_credentials(network_id,legacy_password_hash,legacy_password_salt)
values ('$legacyNetworkId',private.maskan_legacy_password_hash('legacy-network-salt','$legacyNetworkPassword'),'legacy-network-salt');
insert into public.network_members(id,network_id,name,normalized_name)
values ('$legacyMemberId','$legacyNetworkId','Legacy Owner','legacy owner');
insert into private.member_credentials(member_id,legacy_password_hash,legacy_password_salt)
values ('$legacyMemberId',private.maskan_legacy_password_hash('legacy-member-salt','$legacyMemberPassword'),'legacy-member-salt');
update public.networks set created_by_member_id='$legacyMemberId' where id='$legacyNetworkId';
"@
[void](Db-Scalar $legacySql)

$legacyWrong = Invoke-Edge @{
  action = 'verify_member'; networkName = $legacyNetworkName
  memberName = 'Legacy Owner'; memberPassword = 'WrongLegacy42!'
}
Add-Result 'wrong legacy member password rejected' ($legacyWrong.ok -eq $false -and $legacyWrong.code -eq 'invalid_credentials')
Add-Result 'wrong legacy member password does not migrate' ((Db-Scalar "select credential_version from private.member_credentials where member_id='$legacyMemberId'") -eq '1')

$legacyCorrect = Invoke-Edge @{
  action = 'verify_member'; networkName = $legacyNetworkName
  memberName = 'Legacy Owner'; memberPassword = $legacyMemberPassword
}
Add-Result 'correct legacy member password succeeds' ($legacyCorrect.ok -eq $true)
Add-Result 'legacy member upgrades and legacy material is removed' ((Db-Scalar "select count(*) from private.member_credentials where member_id='$legacyMemberId' and credential_version >= 2 and password_digest is not null and legacy_password_hash is null and legacy_password_salt is null") -eq '1')

$legacyLogin = Sign-InMember $legacyMemberId $legacyMemberPassword
Add-Result 'legacy-upgraded Supabase Auth login succeeds' ($null -ne $legacyLogin.access_token)
if ($null -ne $legacyLogin.access_token) {
  [void](Invoke-UserRpc 'maskan_claim_member' @{
    p_member_id = $legacyMemberId; p_claim_token = $legacyCorrect.claimToken
  } $legacyLogin.access_token)
}
Add-Result 'legacy member binds to verified Auth identity' ((Db-Scalar "select count(*) from public.network_members where id='$legacyMemberId' and auth_user_id is not null") -eq '1')
$secondModernLogin = Invoke-Edge @{
  action = 'verify_member'; networkName = $legacyNetworkName
  memberName = 'Legacy Owner'; memberPassword = $legacyMemberPassword
}
Add-Result 'second login uses modern verifier' ($secondModernLogin.ok -eq $true)

$joinerId = [guid]::NewGuid().ToString()
$joinerPassword = 'JoinerOld42!'
$joinerAuth = New-MemberAuth $joinerId $joinerPassword
$networkWrongBefore = Db-Scalar "select updated_at::text from private.network_credentials where network_id='$legacyNetworkId'"
$wrongJoin = Invoke-Edge @{
  action = 'join_network'; networkId = $legacyNetworkId; networkName = $legacyNetworkName
  networkPassword = 'WrongNetwork42!'; memberId = $joinerId
  memberName = 'Joined Member'; memberPassword = $joinerPassword
} $joinerAuth.access_token
$networkWrongAfter = Db-Scalar "select updated_at::text from private.network_credentials where network_id='$legacyNetworkId'"
Add-Result 'wrong legacy network password rejected' ($wrongJoin.ok -eq $false -and $networkWrongBefore -eq $networkWrongAfter)
$joined = Invoke-Edge @{
  action = 'join_network'; networkId = $legacyNetworkId; networkName = $legacyNetworkName
  networkPassword = $legacyNetworkPassword; memberId = $joinerId
  memberName = 'Joined Member'; memberPassword = $joinerPassword
} $joinerAuth.access_token
Add-Result 'correct legacy network password succeeds' ($joined.ok -eq $true)
Add-Result 'legacy network upgrades and new member is modern' ((Db-Scalar "select count(*) from private.network_credentials n join private.member_credentials m on m.member_id='$joinerId' where n.network_id='$legacyNetworkId' and n.credential_version >= 2 and n.legacy_password_hash is null and m.credential_version >= 2 and m.legacy_password_hash is null") -eq '1')

$newJoinerPassword = 'JoinerNew42!'
$reset = Invoke-Edge @{
  action = 'reset_member_password'; networkId = $legacyNetworkId
  adminMemberId = $legacyMemberId; targetMemberId = $joinerId
  newPassword = $newJoinerPassword
} $legacyLogin.access_token
Add-Result 'authorized reset creates modern credential' ($reset.ok -eq $true -and (Db-Scalar "select count(*) from private.member_credentials where member_id='$joinerId' and credential_version >= 2 and legacy_password_hash is null and legacy_password_salt is null") -eq '1')
$oldAuthLogin = Sign-InMember $joinerId $joinerPassword
$oldAppLogin = Invoke-Edge @{
  action = 'verify_member'; networkName = $legacyNetworkName
  memberName = 'Joined Member'; memberPassword = $joinerPassword
}
$newAppLogin = Invoke-Edge @{
  action = 'verify_member'; networkName = $legacyNetworkName
  memberName = 'Joined Member'; memberPassword = $newJoinerPassword
}
$newAuthLogin = Sign-InMember $joinerId $newJoinerPassword
Add-Result 'old password rejected after reset by app and Auth' ($oldAppLogin.ok -eq $false -and $null -eq $oldAuthLogin)
Add-Result 'new password accepted after reset by app and Auth' ($newAppLogin.ok -eq $true -and $null -ne $newAuthLogin.access_token)

$refresh = Try-Auth 'token?grant_type=refresh_token' @{ refresh_token = $newAuthLogin.refresh_token }
Add-Result 'Supabase Auth refresh/session restoration works' ($null -ne $refresh.access_token)
$targetAuthUserId = Db-Scalar "select auth_user_id from public.network_members where id='$joinerId'"
$oldTechnicalPassword = New-TechnicalPassword $joinerId $joinerPassword
[void](Invoke-RestMethod -Method Put -Uri "$apiUrl/auth/v1/admin/users/$targetAuthUserId" `
  -Headers @{ apikey=$local.SERVICE_ROLE_KEY; Authorization="Bearer $($local.SERVICE_ROLE_KEY)" } `
  -ContentType 'application/json' -Body (@{ password=$oldTechnicalPassword } | ConvertTo-Json))
[void](Db-Scalar "update private.member_credentials set auth_password_version=greatest(auth_password_version-1,0) where member_id='$joinerId'")
$healedVerification = Invoke-Edge @{
  action = 'verify_member'; networkName = $legacyNetworkName
  memberName = 'Joined Member'; memberPassword = $newJoinerPassword
}
$healedAuthLogin = Sign-InMember $joinerId $newJoinerPassword
$versionsConverged = Db-Scalar "select (credential_version=auth_password_version)::text from private.member_credentials where member_id='$joinerId'"
Add-Result 'interrupted reset/Auth synchronization self-heals on verified login' (
  $healedVerification.ok -eq $true -and $null -ne $healedAuthLogin.access_token -and $versionsConverged -eq 'true'
)


$crossBefore = Db-Scalar "select updated_at::text from private.member_credentials where member_id='$joinerId'"
$crossReset = Invoke-Edge @{
  action = 'reset_member_password'; networkId = $legacyNetworkId
  adminMemberId = $ownerId; targetMemberId = $joinerId
  newPassword = 'SpoofedReset42!'
} $ownerAuth.access_token
$crossAfter = Db-Scalar "select updated_at::text from private.member_credentials where member_id='$joinerId'"
Add-Result 'cross-network reset and member-ID spoofing denied' ($crossReset.ok -eq $false -and $crossBefore -eq $crossAfter)

$privateDenied = $false
try {
  [void](Invoke-RestMethod -Method Get -Uri "$apiUrl/rest/v1/member_credentials?select=*" -Headers $anonHeaders)
} catch { $privateDenied = $true }
Add-Result 'private credential table is not exposed' $privateDenied

$internalRpcDenied = $false
try {
  [void](Invoke-RestMethod -Method Post -Uri "$apiUrl/rest/v1/rpc/maskan_password_lookup_member" `
    -Headers $anonHeaders -ContentType 'application/json' `
    -Body (@{ p_network_name=$legacyNetworkName; p_member_name='Legacy Owner'; p_member_id=$null } | ConvertTo-Json))
} catch { $internalRpcDenied = $true }
Add-Result 'credential lookup RPC is denied to anon' $internalRpcDenied

$safeHeaders = @{ apikey = $anonKey; Authorization = "Bearer $($ownerAuth.access_token)" }
$safeNetworkRows = Invoke-RestMethod -Method Get -Uri "$apiUrl/rest/v1/maskan_networks?id=eq.$networkId&select=network_password_hash,network_password_salt" -Headers $safeHeaders
$safeMemberRows = Invoke-RestMethod -Method Get -Uri "$apiUrl/rest/v1/maskan_network_members?network_id=eq.$networkId&select=password_hash,password_salt" -Headers $safeHeaders
$safeProjection = $safeNetworkRows.Count -eq 1 -and $null -eq $safeNetworkRows[0].network_password_hash -and $null -eq $safeNetworkRows[0].network_password_salt `
  -and $safeMemberRows.Count -ge 1 -and @($safeMemberRows | Where-Object { $null -ne $_.password_hash -or $null -ne $_.password_salt }).Count -eq 0
Add-Result 'public API projections expose no hash or salt' $safeProjection

$crossExpenseId = [guid]::NewGuid().ToString()
$expenseSql = @"
insert into public.expenses(id,network_id,paid_by_member_id,paid_by_member_name,added_by_member_id,added_by_member_name,amount_cents,note)
values ('$crossExpenseId','$legacyNetworkId','$legacyMemberId','Legacy Owner','$legacyMemberId','Legacy Owner',4200,'cross-network fixture');
"@
[void](Db-Scalar $expenseSql)
$crossRead = Invoke-RestMethod -Method Get -Uri "$apiUrl/rest/v1/expenses?network_id=eq.$legacyNetworkId&select=id" `
  -Headers @{ apikey=$anonKey; Authorization="Bearer $($ownerAuth.access_token)" }
Add-Result 'malicious PostgREST cross-network read returns no rows' ($crossRead.Count -eq 0)
$crossWriteDenied = $false
try {
  $crossPayload = @{
    id=[guid]::NewGuid().ToString(); network_id=$legacyNetworkId
    paid_by_member_id=$legacyMemberId; paid_by_member_name='Legacy Owner'
    added_by_member_id=$legacyMemberId; added_by_member_name='Legacy Owner'; amount_cents=5100
  }
  [void](Invoke-RestMethod -Method Post -Uri "$apiUrl/rest/v1/expenses" `
    -Headers @{ apikey=$anonKey; Authorization="Bearer $($ownerAuth.access_token)"; Prefer='return=minimal' } `
    -ContentType 'application/json' -Body ($crossPayload | ConvertTo-Json))
} catch { $crossWriteDenied = $true }
Add-Result 'malicious PostgREST cross-network write is denied' $crossWriteDenied
$anonEnumerationDenied = $true
foreach ($path in @('maskan_networks', 'maskan_network_members', 'expenses')) {
  try {
    $rows = Invoke-RestMethod -Method Get -Uri "$apiUrl/rest/v1/${path}?select=id" -Headers $anonHeaders
    if ($rows.Count -ne 0) { $anonEnumerationDenied = $false }
  } catch { }
}
Add-Result 'anonymous PostgREST enumeration is denied or empty' $anonEnumerationDenied

$concurrentMemberId = [guid]::NewGuid().ToString()
$concurrentPassword = 'ConcurrentLegacy42!'
$concurrentSql = @"
insert into public.network_members(id,network_id,name,normalized_name)
values ('$concurrentMemberId','$legacyNetworkId','Concurrent Member','concurrent member');
insert into private.member_credentials(member_id,legacy_password_hash,legacy_password_salt)
values ('$concurrentMemberId',private.maskan_legacy_password_hash('concurrent-salt','$concurrentPassword'),'concurrent-salt');
"@
[void](Db-Scalar $concurrentSql)
$concurrentBody = @{
  action = 'verify_member'; networkName = $legacyNetworkName
  memberName = 'Concurrent Member'; memberPassword = $concurrentPassword
} | ConvertTo-Json
$jobs = 1..2 | ForEach-Object {
  Start-Job -ScriptBlock {
    param($Uri, $Key, $Body)
    Invoke-RestMethod -Method Post -Uri $Uri -Headers @{ apikey=$Key; Authorization="Bearer $Key" } `
      -ContentType 'application/json' -Body $Body
  } -ArgumentList "$apiUrl/functions/v1/maskan-password", $anonKey, $concurrentBody
}
$concurrentResponses = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job -Force
Add-Result 'concurrent legacy login requests succeed' (@($concurrentResponses | Where-Object { $_.ok -eq $true }).Count -eq 2)
Add-Result 'concurrent migration leaves one valid modern credential' ((Db-Scalar "select count(*) from private.member_credentials where member_id='$concurrentMemberId' and credential_version >= 2 and password_digest is not null and legacy_password_hash is null and legacy_password_salt is null") -eq '1')

$results | Format-Table -AutoSize
if (@($results | Where-Object Result -eq 'FAIL').Count -gt 0) { exit 1 }
