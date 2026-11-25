# Cross-tenant Azure subscription creation and directory transfer (MCA)

When provisioning an Azure subscription under a Microsoft Customer Agreement (MCA) billing account into a **different** Microsoft Entra tenant (for example, a lab or tenant-to-tenant migration target), Azure enforces tenant-level subscription policies on both directories and a billing-account subscription count cap.

## Prerequisites

- **Billing tenant:** MCA Invoice Section Contributor/Owner (or Billing Account Owner) plus Global Administrator (to elevate access if `blockSubscriptionsLeavingTenant` is enabled).
- **Target tenant:** Global Administrator (to elevate access if `blockSubscriptionsIntoTenant` is enabled). Note that a newly created Entra tenant may enforce MFA registration (`AADSTS50079`) on first CLI sign-in (`az login --tenant <target-tenant-id> --allow-no-subscriptions`).

## 1. Configure subscription policy exemptions in both tenants

Both the source and destination Entra tenants commonly default to `blockSubscriptionsLeavingTenant: true` and `blockSubscriptionsIntoTenant: true` with `exemptedPrincipals: []`.

1. Check the current tenant's policy:

   ```powershell
   az rest --method get --url "https://management.azure.com/providers/Microsoft.Subscription/policies/default?api-version=2021-10-01" -o json
   ```

2. If `PUT` returns `403 UserNotAuthorized` (`User doesn't have 'UserAccessAdministrator' role at root scope (/)`), elevate access as Global Administrator:

   ```powershell
   az rest --method post --url "https://management.azure.com/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01"
   ```

3. Add the caller's object ID **in that specific tenant** (`az ad signed-in-user show --query id -o tsv`) to `exemptedPrincipals`. Note that `PUT /providers/Microsoft.Subscription/policies/default?api-version=2021-10-01` expects **top-level fields** (wrapping them in `properties` returns `200 OK` without updating `exemptedPrincipals`):

   ```powershell
   $tmp = [System.IO.Path]::GetTempFileName()
   $json = @{
     blockSubscriptionsIntoTenant    = $true
     blockSubscriptionsLeavingTenant = $true
     exemptedPrincipals              = @("<principal-object-id-in-that-tenant>")
   } | ConvertTo-Json -Depth 5
   [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
   az rest --method put --url "https://management.azure.com/providers/Microsoft.Subscription/policies/default?api-version=2021-10-01" --body "@$tmp" -o json
   Remove-Item -LiteralPath $tmp -Force
   ```

4. Switch to the target tenant (`az login --tenant <target-tenant-id> --allow-no-subscriptions`) and repeat steps 1-3 using the caller's object ID in the target tenant.

## 2. Create a subscription in the target tenant

Authenticate against the billing (source) tenant and pass `additionalProperties.subscriptionTenantId`:

```powershell
$tmp = [System.IO.Path]::GetTempFileName()
$json = @{
  properties = @{
    displayName  = "<subscription-display-name>"
    billingScope = "/providers/Microsoft.Billing/billingAccounts/<billing-account-id>/billingProfiles/<billing-profile-id>/invoiceSections/<invoice-section-id>"
    workload     = "Production"
    additionalProperties = @{
      subscriptionTenantId = "<target-tenant-id>"
    }
  }
} | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
az rest --method put --url "https://management.azure.com/providers/Microsoft.Subscription/aliases/<alias-name>?api-version=2021-10-01" --body "@$tmp" -o json
Remove-Item -LiteralPath $tmp -Force
```

If this fails with `NotAllowed` / `SubscriptionCountReachedLimit`, the MCA billing account has reached its subscription limit across all linked tenants. Open an Azure Billing support request with the billing account ID and error payload, or transfer an unused empty subscription (next section).

## 3. Transfer an existing empty subscription across tenants

> **Important:** Only transfer an **empty** subscription (or plan to recreate all directory-bound access). Changing a subscription's Entra directory removes all RBAC role assignments, breaks Managed Identities, and breaks Entra-bound resources such as Key Vault tenant links and Entra-joined AVD session hosts.

1. **Initiate the transfer (source tenant token):**

   ```powershell
   $srcToken = az account get-access-token --tenant <source-tenant-id> --query accessToken -o tsv
   $body = @{
     properties = @{
       destinationTenantId = "<target-tenant-id>"
       destinationOwnerId  = "<target-owner-object-id-in-target-tenant>"
     }
   } | ConvertTo-Json -Depth 5
   Invoke-RestMethod -Method Put `
     -Uri "https://management.azure.com/subscriptions/<subscription-id>/providers/Microsoft.Subscription/changeTenantRequest/default?api-version=2025-11-01-preview" `
     -Headers @{ Authorization = "Bearer $srcToken"; "Content-Type" = "application/json" } `
     -Body $body
   ```

   *(Using `Invoke-RestMethod` with `az account get-access-token` avoids `az rest` failing with `Subscription not found` when a newly created subscription is not yet in the local CLI cache.)*

2. **Accept the transfer (target tenant token):**

   ```powershell
   $dstToken = az account get-access-token --tenant <target-tenant-id> --query accessToken -o tsv
   $acceptBody = @{ properties = @{ displayName = "<subscription-display-name>" } } | ConvertTo-Json -Depth 5
   Invoke-RestMethod -Method Post `
     -Uri "https://management.azure.com/providers/Microsoft.Subscription/subscriptions/<subscription-id>/acceptChangeTenant?api-version=2025-11-01-preview" `
     -Headers @{ Authorization = "Bearer $dstToken"; "Content-Type" = "application/json" } `
     -Body $acceptBody
   ```

3. **Verify completion:**

   Poll `GET /subscriptions/<subscription-id>/providers/Microsoft.Subscription/changeTenantRequest/default?api-version=2025-11-01-preview` with `$srcToken` until `properties.status` is `Completed`. ARM tenant-issuer propagation can take a few minutes (up to 1 hour; `InvalidAuthenticationTokenTenant` is expected transiently during propagation) before `az account list --refresh --all` shows the subscription under `<target-tenant-id>`.
