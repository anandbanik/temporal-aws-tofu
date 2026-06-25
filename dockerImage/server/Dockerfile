# syntax=docker/dockerfile:1
FROM temporalio/server:1.31.0

COPY --chmod=755 ./scripts/ /scripts/

CMD ["/scripts/entrypoint.sh"]