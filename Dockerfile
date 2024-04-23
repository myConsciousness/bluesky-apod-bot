FROM dart:latest as build-image

WORKDIR /work
COPY ./ ./

RUN dart pub get
RUN dart compile exe ./src/main.dart -o ./bootstrap
RUN chmod +x bootstrap

FROM public.ecr.aws/lambda/provided:latest

COPY --from=build-image /work/bootstrap /var/runtime/

CMD ["dummyHandler"]
