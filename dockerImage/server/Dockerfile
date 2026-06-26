# syntax=docker/dockerfile:1
FROM temporalio/server:1.31.0

COPY --chmod=755 ./scripts/ /scripts/
COPY --chmod=755 ./config/dynamicConfig/development-sql.yaml /etc/temporal/dynamicconfig/development-sql.yaml

CMD ["/scripts/entrypoint.sh"]