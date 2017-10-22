FROM openjdk:8

ARG DB_HOST
ARG DB_PORT
ARG DB_NAME
ARG DB_USER
ARG DB_PASS
ARG LOGIN_HOST=localhost
ARG WEBAPP_FILENAME

EXPOSE 9000
WORKDIR demo3
COPY ${WEBAPP_FILENAME} ${WEBAPP_FILENAME}
RUN apt-get update && apt-get install -y mc && \
    java -jar ${WEBAPP_FILENAME}