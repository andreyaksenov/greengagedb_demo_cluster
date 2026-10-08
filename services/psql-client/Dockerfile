FROM alpine:3.24

RUN apk add --no-cache postgresql-client bash

RUN adduser -D -s /bin/bash alice \
    && echo "alice:qwerty" | chpasswd

USER alice
WORKDIR /home/alice

CMD ["sleep", "infinity"]
