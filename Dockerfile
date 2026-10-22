# Образ должен собираться воспроизводимо, поэтому базовый образ закреплён по digest,
# SOURCE_DATE_EPOCH убирает дату из /etc/shadow, а .pyc не создаются.
# В final нет RUN после COPY --from: Kaniko не учёл бы скопированные файлы в ключе кэша.

ARG PYTHON_IMAGE=python:3.11-slim-bookworm@sha256:0a310eeecf4e1f5a0743f9a6520c90c88d089c903ca5fd283f501e3a805f5f89

FROM ${PYTHON_IMAGE} AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    SOURCE_DATE_EPOCH=0


FROM base AS build
SHELL ["/bin/sh", "-eu", "-c"]
WORKDIR /build

RUN python -m pip install --no-warn-script-location "poetry==1.8.*"

COPY pyproject.toml poetry.lock ./
RUN mkdir -p dist \
 && poetry export --without-hashes --format constraints.txt --output dist/constraints.txt \
 && python -m pip wheel --isolated --requirement dist/constraints.txt --wheel-dir dist/vendor

COPY README.md ./
COPY src/ src/
# --ignore-installed: idna и ещё часть зависимостей уже стоят здесь вместе с Poetry,
# без флага pip не положит их в /install
RUN poetry build --format wheel \
 && python -m pip install \
      --isolated --no-index --no-deps --no-compile --no-warn-script-location \
      --ignore-installed \
      --prefix /install \
      dist/vendor/*.whl dist/*.whl


FROM base AS final

ARG USER=audit
ARG UID=10001
ARG GID=10001
RUN groupadd --gid "${GID}" "${USER}" \
 && useradd --uid "${UID}" --gid "${GID}" --no-create-home --no-log-init \
      --home-dir /nonexistent --shell /usr/sbin/nologin "${USER}"

COPY --from=build /install /usr/local

USER ${UID}:${GID}
ENV HOST=0.0.0.0 \
    PORT=8080 \
    AUDIT_SVC_CONFIG=/etc/audit-svc/config.yaml
EXPOSE 8080
CMD ["server"]
