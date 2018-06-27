FROM openjdk:8-jdk-alpine

# Create app directory
WORKDIR /usr/src/app

ARG JAR_FILE
COPY ${JAR_FILE} app.jar
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/usr/src/app/app.jar"]