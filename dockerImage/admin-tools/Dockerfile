FROM temporalio/admin-tools:1.31.0

COPY ./scripts/ /scripts/
RUN chmod +x /scripts/setup-postgres.sh

CMD ["/scripts/setup-postgres.sh"]