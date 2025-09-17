FROM maven:3-eclipse-temurin-17 AS build  
COPY src /usr/src/app/src 
COPY pom.xml /usr/src/app
COPY _courses _courses

ARG VARIANT=none

RUN if [ -d "_courses/$VARIANT" ]; then \
        echo $VARIANT; \
        patch < _courses/$VARIANT/init.patch; \
    fi

WORKDIR /usr/src/app
RUN --mount=type=cache,target=/root/.m2 mvn package -Dmaven.test.skip

FROM eclipse-temurin:17

WORKDIR /usr/src/app

COPY --from=build /usr/src/app/target/recorder-0.0.1-SNAPSHOT.jar /usr/src/app/recorder.jar
RUN mkdir /usr/src/app/lib
EXPOSE 9003
ENTRYPOINT ["java", "-jar", "/usr/src/app/recorder.jar"]
