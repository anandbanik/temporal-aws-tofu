// @@@SNIPSTART money-transfer-java-workflow-implementation
package com.temporal.money.transfer.workflow;

import io.temporal.activity.ActivityOptions;
import io.temporal.workflow.Workflow;
import io.temporal.common.RetryOptions;
import io.temporal.spring.boot.WorkflowImpl;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.temporal.money.transfer.activity.AccountActivity;
import com.temporal.money.transfer.activity.AccountActivityImpl;
import com.temporal.money.transfer.model.TransactionDetails;

@WorkflowImpl(workers = "money-transfer")
public class MoneyTransferWorkflowImpl implements MoneyTransferWorkflow {

	private static Logger log = LoggerFactory.getLogger(MoneyTransferWorkflowImpl.class);

	private static final String WITHDRAW = "Withdraw";

	// RetryOptions specify how to automatically handle retries when Activities fail
	private final RetryOptions retryoptions = RetryOptions.newBuilder().setInitialInterval(Duration.ofSeconds(1)) // Wait
																													// 1
																													// second
																													// before
																													// first
																													// retry
			.setMaximumInterval(Duration.ofSeconds(20)) // Do not exceed 20 seconds between retries
			.setBackoffCoefficient(2) // Wait 1 second, then 2, then 4, etc
			.setMaximumAttempts(5000) // Fail after 5000 attempts
			.build();

	// ActivityOptions specify the limits on how long an Activity can execute before
	// being interrupted by the Orchestration service
	private final ActivityOptions defaultActivityOptions = ActivityOptions.newBuilder().setRetryOptions(retryoptions) // Apply
																														// the
																														// RetryOptions
																														// defined
																														// above
			.setStartToCloseTimeout(Duration.ofSeconds(2)) // Max execution time for single Activity
			.setScheduleToCloseTimeout(Duration.ofSeconds(5000)) // Entire duration from scheduling to completion
																	// including queue time
			.build();

	private final Map<String, ActivityOptions> perActivityMethodOptions = new HashMap<String, ActivityOptions>() {
		{
			// A heartbeat time-out is a proof-of life indicator that an activity is still
			// working.
			// The 5 second duration used here waits for up to 5 seconds to hear a
			// heartbeat.
			// If one is not heard, the Activity fails.
			// The `withdraw` method is hard-coded to succeed, so this never happens.
			// Use heartbeats for long-lived event-driven applications.
			put(WITHDRAW, ActivityOptions.newBuilder().setHeartbeatTimeout(Duration.ofSeconds(5)).build());
		}
	};

	// ActivityStubs enable calls to methods as if the Activity object is local but
	// actually perform an RPC invocation
	private final AccountActivity accountActivityStub = Workflow.newActivityStub(AccountActivity.class,
			defaultActivityOptions, perActivityMethodOptions);

	// The transfer method is the entry point to the Workflow
	// Activity method executions can be orchestrated here or from within other
	// Activity methods
	@Override
	public void transfer(TransactionDetails transaction) {
		// Retrieve transaction information from the `transaction` instance
		String sourceAccountId = transaction.getSourceAccountId();
		String destinationAccountId = transaction.getDestinationAccountId();
		String transactionReferenceId = transaction.getTransactionReferenceId();
		int amountToTransfer = transaction.getAmountToTransfer();

		// Stage 1: Withdraw funds from source
		try {
			// Launch `withdrawal` Activity
			accountActivityStub.withdraw(sourceAccountId, transactionReferenceId, amountToTransfer);
		} catch (Exception e) {
			// If the withdrawal fails, for any exception, it's caught here
			log.error(transactionReferenceId + " Withdrawal of " + amountToTransfer + " from account " + sourceAccountId
					+ " failed");
			System.out.flush();

			// Transaction ends here
			return;
		}

		// Stage 2: Deposit funds to destination
		try {
			// Perform `deposit` Activity
			accountActivityStub.deposit(destinationAccountId, transactionReferenceId, amountToTransfer);

			// The `deposit` was successful
			log.info(transactionReferenceId + " Transaction succeeded.", transactionReferenceId);
			System.out.flush();

			// Transaction ends here
			return;
		} catch (Exception e) {
			// If the deposit fails, for any exception, it's caught here
			log.error(transactionReferenceId + " Deposit of " + amountToTransfer + " to account " + destinationAccountId
					+ " failed.");
			System.out.flush();
		}

		// Continue by compensating with a refund

		try {
			// Perform `refund` Activity
			log.info(transactionReferenceId + " Refunding " + amountToTransfer + " to account " + sourceAccountId);
			System.out.flush();

			accountActivityStub.refund(sourceAccountId, transactionReferenceId, amountToTransfer);

			// Recovery successful. Transaction ends here
			log.info(transactionReferenceId + " Refund to originating account was successful.");
			log.info(transactionReferenceId + " Transaction is complete. No transfer made");
			return;
		} catch (Exception e) {
			// A recovery mechanism can fail too. Handle any exception here
			log.error(transactionReferenceId + " Deposit of " + amountToTransfer + " to account " + destinationAccountId
					+ " failed. Did not compensate withdrawal.");
			log.error(transactionReferenceId + " Workflow failed.");
			System.out.flush();

			// Rethrowing the exception causes a Workflow Task failure
			throw (e);
		}
	}
}
// @@@SNIPEND
