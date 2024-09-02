FROM arm64v8/dart:latest as build-image

WORKDIR /work
COPY ./ ./

RUN dart pub get
RUN dart compile exe ./src/main.dart -o ./bootstrap --verbosity=all
RUN chmod +x bootstrap

FROM --platform=linux/arm64 public.ecr.aws/lambda/provided:latest

COPY --from=build-image /work/bootstrap /var/runtime/

CMD ["dummyHandler"]
