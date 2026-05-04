# Multi-stage pattern
FROM python:3.12-slim AS builder
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt
RUN python -m pytest                    # test trong builder

FROM python:3.12-slim AS production
COPY --from=builder /install /usr/local # chỉ copy artifacts
COPY app.py .                           # không copy test files

# ARG vs ENV
ARG VERSION=1.0.0                       # build-time only
ENV APP_VERSION=${VERSION}              # runtime (từ ARG)

# Entrypoint pattern
COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT ["entrypoint.sh"]           # setup script
CMD ["gunicorn", "app:app"]            # default command

# Security
RUN adduser --disabled-password appuser
USER appuser                           # non-root
--read-only                            # filesystem read-only
--tmpfs /tmp                           # writable temp

# Size optimization
RUN pip install --no-cache-dir ...     # no pip cache
RUN apt-get install && rm -rf /var/lib/apt/lists/*
.dockerignore                          # exclude unnecessary files