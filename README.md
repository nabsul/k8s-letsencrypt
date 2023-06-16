# Let's Encrypt for Kubernetes: The "Hard" Way

This repo shows you how to manage Let's Encrypt certificates in your Kubernetes cluster without the use of automation.
Normally, you should be fine using something like [cert-manager](https://cert-manager.io/docs/) or [Traefik](https://traefik.io)
to automatically manage your certs.
However, when these tools fail it's good to have a backup plan to keep your certificates up to date.
That's where this repo comes in.

Note: The following instructions are for using the `http` validation method.
If you prefer to use the DNS method, you can skip the `acme-challenge` service creation and path routing steps.

## How to Use This Repo

You can either use the two provided yaml files as-is in your cluster,
or, if you'd like to have more control and customization,
build the admin Docker image yourself and tweak the yaml files according to your needs.

The following sections show how to use this code:

## HTTP Method Validation

The following sections describe how to create your certs using the HTTP Method.

### Step 1 (Optional): Build the Admin Image

The Admin pod is just a Debian image with `certbot` and `kubectl` pre-installed.
If you trust my work,
you can go ahead and use the public Docker Hub image I have published at `nabsul/k8s-admin:v002`.
But to be honest, you really shouldn't trust Docker images from strangers.
For this reason, I personally recommend building the admin image yourself:

You can also build the docker image yourself using the included Dockerfile,
or even deploy a base image and manually install `certbot` and `kubectl` once you log in.
If you go this route you'll need to tweak the `image` field at the end of the `admin.yaml` accordingly.

### Step 2: Deploy the admin Image and acme-challenge Service

The Admin pod will need permissions to create certificates.
The `admin.yaml` file deploys the pod and grants it access to manage secrets in your cluster.
To create the admin pod, simply run:

```sh
kubectl apply -f admin.yaml
```

The `acme-challenge` service is just a plain `nginx` pod.
We will be routing requests to the `/.well-known/acme-challenge` path to this pod
for the validation step needed to create Let's Encrypt certificates.
The service can be created with the following command:

```sh
kubectl apply -f acme-challenge.yaml
```

### Step 3: Route Path to the acme-challenge Service

You'll need to route requests to the `/.well-known/acme-challenge` path to the `acme-challenge` service.
To do this, go to your Ingress definition and add the following as the first entry in your `paths` section:

```yaml
      - backend:
          service:
            name: acme-challenge
            port:
              number: 80
        path: /.well-known/acme-challenge
        pathType: Prefix
```

For example, your complete ingress file should look like this:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: mytest.test
    http:
      paths:
      - backend:
          service:
            name: acme-challenge
            port:
              number: 80
        path: /.well-known/acme-challenge
        pathType: Prefix
      - backend:
          service:
            name: hello-world
            port:
              number: 80
  tls:
  - hosts:
    - mytest.test
    secretName: test-tls
```

### Step 4: Run CertBot

Now we'll log into the admin pod to create our certificate:

```sh
kubectl exec -it k8s-admin -- bash
```

You should now see the Debian bash prompt of the admin pod.
You can now start the process of issuing the certificate with the following command:

```sh
certbot certonly --manual --preferred-challenges http -d [mydomain.com],[mydomain.org],[mydomain.net]
```

You will have to provide your email address and agree to some terms.
You will then be asked to create a file with content like this:

```sh
Create a file containing just this data:

2RzV_b85lAE2wPn_Nf-UJzdVkxPjxgw8_6oEtPpV6ls.ABCABC_1dedKwm_TsyyDkbIsd76jnfrn5a_XrwkPkHU

And make it available on your web server at this URL:

http://[your-domain]/.well-known/acme-challenge/ABSABV_b85lAE2wPn_Nf-UJzdVkxPjxgw8_6oEtPpV6ls
```

Leave this window/tab open and move on to the next step:

### Step 5: Copy Code to the acme-challenge Service

In a new shell window/tab you'll need to log into your nginx service.

```sh
kubectl exec -it acme-challenge -- bash
```

We'll now navigate to the html content directory and create a couple of empty directories:

```sh
cd /usr/share/nginx/html/
mkdir -p .well-known/acme-challenge
cd .well-known/acme-challenge
```

Finally, we'll create the file that was requested in the previous step. For example:

```sh
echo "2RzV_b85lAE2wPn_Nf-UJzdVkxPjxgw8_6oEtPpV6ls.ABCABC_1dedKwm_TsyyDkbIsd76jnfrn5a_XrwkPkHU" > ABSABV_b85lAE2wPn_Nf-UJzdVkxPjxgw8_6oEtPpV6ls
```

### Step 6: Create a Kubernetes Secret

Now we will return to the first window/tab and press "enter" to continue.
If everything was done correctly, it should report a success message like so:

```sh
Press Enter to Continue
Waiting for verification...
Cleaning up challenges

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/[your-domain]/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/[your-domain]/privkey.pem
   Your cert will expire on 2021-01-21. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot
   again. To non-interactively renew *all* of your certificates, run
   "certbot renew"
```

We will navigate to the directory shown above:

```sh
cd /etc/letsencrypt/live/[your-domain]
```

And finally, we'll create our ssl cert in Kubernetes with the following command.
If the secret already exists, you'll first need to delete it.
You can skip the delete command if it doesn't already exist:

```sh
kubectl delete secret [your-cert-name]
kubectl create secret tls [your-cert-name] --cert=fullchain.pem --key=privkey.pem
```

### Step 7: Clean Up

You don't need to keep the admin pod running after you've issued your certificates.
To delete the admin pod and acme-challenge service, you can run the following two commands:

```sh
kubectl delete -f admin.yaml
kubectl delete -f acme-challenge.yaml
```

You can also remove the `.well-known` path entry from the Ingress configuration.

## DNS Validation Method

I won't go into as much detail for the DNS method.
It's very similar to the HTTP method except:

- No need to deploy the `acme-challenge` service
- No need to add the `/.well-known/acme-challenge` path to the ingress configuration
- Use `--preferred-challenges dns` in the `certbot` command instead of `--preferred-challenges http`
- Instead of creating a file in the nginx pod, you'll create a txt entry in your domain configuration
