1. DuckDNS side (once, in the browser)
Sign in at duckdns.org and create a subdomain, e.g. myhomelab, which gives myhomelab.duckdns.org.
Copy your token from the top of the page. It controls all your subdomains, so treat it as a secret.
Point the A record at the PVE host’s LAN IP, not your public IP. In the browser (or with curl) open:
   <https://www.duckdns.org/update?domains=myhomelab&token=YOUR_TOKEN&ip=192.168.1.X>

Replace X with the address of the PVE host’s vmbr0. If you leave ip= out, DuckDNS stores your public IP, and the name wouldn’t reach the host from inside your LAN.

A private IP in public DNS is fine for ACME, because validation uses the TXT record, not the A record.

1. Make the name resolve on your LAN

Some routers block public DNS answers that point to private addresses (“DNS rebinding protection”). Check from a LAN machine:

nslookup myhomelab.duckdns.org

If it returns 192.168.1.X, you’re done. If it fails or returns nothing, either whitelist duckdns.org in the router’s rebinding setting, or add a local DNS record in Pi-hole (Local DNS → DNS Records) for the same name. The Pi-hole option works anywhere and doesn’t depend on the router.

1. Terraform side

Get the current Let’s Encrypt terms-of-service URL from the directory instead of copying it from anywhere:

curl -s <https://acme-v02.api.letsencrypt.org/directory> | grep termsOfService

Then set the values. Secrets go in terraform/_shared/.env, which stays gitignored:

bash
export TF_VAR_acme_contact='<you@example.com>'
export TF_VAR_acme_dns_data='{"DuckDNS_Token":"YOUR_TOKEN"}'

And in terraform.tfvars for 00-bootstrap:

hcl
acme_enabled   = true
acme_domain    = "myhomelab.duckdns.org"
acme_tos_url   = "<url from the curl above>"
acme_dns_api   = "duckdns"
acme_directory = "<https://acme-staging-v02.api.letsencrypt.org/directory>"  # staging first

DuckDNS_Token is the exact variable name the acme.sh duckdns script expects. A wrong key name fails with a missing-token error.

1. Rollout
task apply STAGE=00-bootstrap with the staging directory. The result is an untrusted certificate, which proves the DNS plugin and order flow work without touching production rate limits.
Switch acme_directory to the production URL and apply again. Changing the directory re-registers the ACME account.
Open <https://myhomelab.duckdns.org:8006/>, which should show a trusted certificate.
Set proxmox_endpoint to that URL and proxmox_insecure = false in every stage.
