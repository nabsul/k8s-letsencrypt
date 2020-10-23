FROM debian:buster

RUN apt-get update
RUN apt-get install -y curl nano certbot
RUN curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
RUN chmod 755 kubectl && mv kubectl /usr/local/bin/

CMD tail -f /dev/null
