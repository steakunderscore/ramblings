---
title: "Setting Up"
date: 2019-11-15T23:53:43Z
disqus: false
---

## Getting started

Having used jekyll before for other blogs, but this time I wanted to switch to [Hugo](https://gohugo.io/). For hosting I am going to see how I go hosting purely on GCP. I'll be using a GSC bucket and a GCP load balancer.

### Installing Hugo:

```
go get -v -u github.com/gohugoio/hugo
```

But then after looking at a theme which used scss, `hugo server` was giving this error:

```
Building sites … ERROR 2019/11/15 21:34:38 error: failed to transform resource: TOCSS: failed to transform "scss/style.scss" (text/x-scss): this feature is not available in your current Hugo version
```

It turns out the solution is in the [Hugo Troubleshooting FAQ](https://gohugo.io/troubleshooting/faq/#i-get-tocss-this-feature-is-not-available-in-your-current-hugo-version). Which for me translated in to fixing it in the go path
```
cd $GOPATH/src/github.com/gohugoio/hugo
go install --tags extended
```

### Setting up theme

After trying a theme, I settled on [ezhil](https://github.com/vividvilla/ezhil). I decided that there's a good chance I would want to make minor modifications, so instead of using git submodules, I decided just to vendorise the theme.
```
git clone https://github.com/vividvilla/ezhil.git themes/ezhil
rm -rf themes/ezhil/.git
```

Now just to update the `config.toml`

```
cp themes/ezhil/README.md config.toml
```

Then edit away `vim config.toml`.

## Hosting

For hosting, I have decided to use [GCS](https://cloud.google.com/storage/). Generally I'll just be following the [Hugo guide](https://gohugo.io/hosting-and-deployment/hugo-deploy/) for this. I'll also be starting a new GCP project from scratch.

### GCP Project setup

I set up a new configuration with my specifics, because it's specific to the task, I'll drop the details. Except I will show (re-)activating the configuration profile.
```
gcloud init
gcloud config configurations activate ramblings
```

Linking a billing account
```
gcloud beta billing accounts list
gcloud beta billing projects link hj-ramblings \
    --billing-account=000000-000000-000000
```

### Bucket setup

I think europe-west2 ( London ) is best for now. Can always revisit later if need be.
```
gsutil mb -l eu gs://ramblings.henryjenkins.name
gsutil defacl ch -u AllUsers:R gs://ramblings.henryjenkins.name
gsutil web set -m index.html -e 404.html gs://ramblings.henryjenkins.name
```

Add some deployment settings to Hugo
```
cat <<EOF >> config.toml

[deployment]
# Upload images first
order = [".jpg$", ".gif$"]

[[deployment.targets]]
# An arbitrary name for this target.
name = "ramblings-gcs"
URL = "gs://ramblings.henryjenkins.name"

[[deployment.matchers]]
#  Cache static assets for 1 year
pattern = "^.+\\.(js|css|svg|ttf)$"
cacheControl = "max-age=31557600, no-transform, public"
gzip = true

[[deployment.matchers]]
pattern = "^.+\\.(png|jpg)$"
cacheControl = "max-age=31557600, no-transform, public"
gzip = false

[[deployment.matchers]]
pattern = "^.+\\.(html|xml|json)$"
gzip = true
EOF
```

Now lets test it all!

oh..
```
hugo deploy
Deploying to target "ramblings-gcs" (gs://ramblings.henryjenkins.name)
Error: open bucket gs://ramblings.henryjenkins.name: google: could not find default credentials. See https://developers.google.com/accounts/docs/application-default-credentials for more information.
```
Some error I don't understand, but [someone else](https://github.com/circleci/docker-hello-google/issues/5#issuecomment-429754019) has the answer
```
gcloud auth application-default login
```

Now, success!
```
hugo
hugo deploy
```

Now I can see it loading from https://storage.cloud.google.com/ramblings.henryjenkins.name/index.html

## Now, sharing the bucket with a load balancer

Create some reserved IP addresses
```
gcloud compute addresses create ramblings-henryjenkins-name-ipv4 --ip-version=IPV4 --global
gcloud compute addresses create ramblings-henryjenkins-name-ipv6 --ip-version=IPV6 --global
```

Setup a new DNS zone to use, I would prefer this than putting the records straight in to my registrar
```
gcloud dns managed-zones create ramblings-henryjenkins-name --dns-name="ramblings.henryjenkins.name" --visibility=public --description=""
```

Setting DNS records
```
IPv4_addr=$(gcloud compute addresses describe ramblings-henryjenkins-name-ipv4 --format="get(address)" --global)
IPv6_addr=$(gcloud compute addresses describe ramblings-henryjenkins-name-ipv6 --format="get(address)" --global)
gcloud dns record-sets transaction start --zone ramblings-henryjenkins-name
gcloud dns record-sets transaction add "${IPv4_addr}" --name ramblings.henryjenkins.name --ttl 300 --type A --zone ramblings-henryjenkins-name
gcloud dns record-sets transaction add "${IPv6_addr}" --name ramblings.henryjenkins.name --ttl 300 --type AAAA --zone ramblings-henryjenkins-name
gcloud dns record-sets transaction execute --zone ramblings-henryjenkins-name
```

Then I set up the DNS with my registrar
```
ramblings 1800 IN NS ns-cloud-a1.googledomains.com.
ramblings 1800 IN NS ns-cloud-a2.googledomains.com.
ramblings 1800 IN NS ns-cloud-a3.googledomains.com.
ramblings 1800 IN NS ns-cloud-a4.googledomains.com.
```

Create back-end bucket (enable Cloud CDN)
```
gcloud compute backend-buckets create ramblings-henryjenkins-name-bucket --gcs-bucket-name ramblings.henryjenkins.name --enable-cdn
```

Create a new SSL certificate, google managed (Lets Encrypt)
```
gcloud beta compute ssl-certificates create ramblings-henryjenkins-name --global --domains ramblings.henryjenkins.name --description "SSL Cert for ramblings.henryjenkins.name"
```
Note: Using beta here as creating GCP managed certs is still in beta.

Create host and path rule pointing to back-end bucket
```
gcloud compute url-maps create ramblings-henryjenkins-name-map --default-backend-bucket ramblings-henryjenkins-name-bucket
gcloud compute target-https-proxies create https-ramblings-henryjenkins-name-proxy --url-map ramblings-henryjenkins-name-map --ssl-certificates ramblings-henryjenkins-name
gcloud compute forwarding-rules create https-ramblings-henryjenkins-name-ipv4 --address=ramblings-henryjenkins-name-ipv4 --global --target-https-proxy=https-ramblings-henryjenkins-name-proxy --ports=443
gcloud compute forwarding-rules create https-ramblings-henryjenkins-name-ipv6 --address=ramblings-henryjenkins-name-ipv6 --global --target-https-proxy=https-ramblings-henryjenkins-name-proxy --ports=443
```

I guess I should support good old http too
```
gcloud compute target-http-proxies create http-ramblings-henryjenkins-name-proxy --url-map ramblings-henryjenkins-name-map
gcloud compute forwarding-rules create http-ramblings-henryjenkins-name-ipv4 --address=ramblings-henryjenkins-name-ipv4 --global --target-http-proxy=http-ramblings-henryjenkins-name-proxy --ports=80
gcloud compute forwarding-rules create http-ramblings-henryjenkins-name-ipv6 --address=ramblings-henryjenkins-name-ipv6 --global --target-http-proxy=http-ramblings-henryjenkins-name-proxy --ports=80
```

After waiting a while for `gcloud beta compute ssl-certificates describe  ramblings-henryjenkins-name --global` to change from `PROVISIONING` to `ACTIVE`.

Success! We can now visit https://ramblings.henryjenkins.name/

Edit: So I didn't look at the price. It's going to pan out to be about 20 USD per month. I think in the near future I might find a different method of hosting.

References:

1. https://gohugo.io/hosting-and-deployment/hugo-deploy/
2. https://cloud.google.com/load-balancing/docs/https/adding-backend-buckets-to-load-balancers
3. https://cloud.google.com/dns/records/
4. https://cloud.google.com/load-balancing/docs/url-map
5. https://cloud.google.com/load-balancing/docs/https/setting-up-https
