# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 temporalio/admin-tools:1.31.0

COPY --chmod=755 ./scripts/ /scripts/

CMD ["/scripts/setup-postgres.sh"]