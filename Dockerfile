FROM debian:stable-slim
RUN apt update \
    && apt -y install gnupg2 curl zip unzip jq \
    && gpg --list-keys

ADD public_key_filename.txt /tmp

RUN curl -Lo /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest && curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip

RUN gpg --import /tmp/public_key_filename.txt && curl -Lo ecs-cli.asc https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest.asc && gpg --verify ecs-cli.asc /usr/local/bin/ecs-cli

RUN chmod +x /usr/local/bin/ecs-cli && ecs-cli --version

RUN unzip /tmp/awscliv2.zip && ./aws/install -i /usr/local/aws-cli -b /usr/local/bin

ADD entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]